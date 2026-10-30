local log = Log.open_topic("s-wm2-volume-sync")

local SRC = "capture.wm2_speakers"
local DST = "alsa_output.pci-0000_64_00.6.analog-stereo"

-- Core.require_api() does nothing inside the daemon; the plugin is made
-- available by `requires = [ api.mixer ]` in the conf drop-in.
local mixer = Plugin.find("mixer-api")
if not mixer then
  log.warning("mixer-api plugin not available; is `requires = [ api.mixer ]` set in the conf?")
  return
end

-- DST = SRC + DST_OFFSET dB, clamped to 0 dB (linear 1.0, top of the hardware range).
-- Below -DST_OFFSET dB on SRC the filter-chain post_gain holds -DST_OFFSET dB and DST attenuates;
-- above it DST sits at 0 dB and post_gain takes over.
local DST_OFFSET = 14.285 -- +23 dB as linear amplitude
local DST_MAX = 1.0 -- 0 dB

local ids = {}

-- mixer-api returns/accepts volumes in its "scale" property (shared plugin,
-- so read it rather than set it). Same conversions as module-mixer-api.c.
local function to_linear(v)
  if v <= 0 then return 0.0 end
  if mixer["scale"] == "cubic" then return v * v * v end
  return v
end

local function from_linear(v)
  if v <= 0 then return 0.0 end
  if mixer["scale"] == "cubic" then return v ^ (1 / 3) end
  return v
end

local function sync()
  if not (ids[SRC] and ids[DST]) then return end
  local v = mixer:call("get-volume", ids[SRC])
  if not v or not v.volume then return end
  local dst = math.min(to_linear(v.volume) * DST_OFFSET, DST_MAX)
  mixer:call("set-volume", ids[DST], {
    volume = from_linear(dst),
    mute = v.mute,
  })
  log.info(string.format(
    "volume %.3f (linear %.3f) mute %s -> node %d linear %.3f",
    v.volume, to_linear(v.volume), tostring(v.mute), ids[DST], dst
  ))
end

-- "changed" fires with the node id whenever a node's volume/mute changes.
-- We only react to SRC; writing to DST does not retrigger us.
mixer:connect("changed", function (_, id)
  if id == ids[SRC] then sync() end
end)

-- Global on purpose: keeps the object manager referenced for the script's lifetime.
om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "media.class", "=", "Audio/Sink" },
  },
}

om:connect("object-added", function (_, node)
  local name = node.properties["node.name"]
  if name == SRC or name == DST then
    ids[name] = node["bound-id"]
    sync()
    -- the mixer may not have the node's volume cached yet, so retry once shortly after
    Core.timeout_add(500, function () sync() return false end)
  end
end)

om:connect("object-removed", function (_, node)
  local name = node.properties["node.name"]
  if name == SRC or name == DST then ids[name] = nil end
end)

om:activate()
