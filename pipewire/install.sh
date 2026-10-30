#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "${0}")"

if [[ "${UID}" == "0" ]]; then
  echo "Error: System-level install is not supported. Run as a user."
  exit 1
fi

pw_conf_dir="${HOME}/.config/pipewire/pipewire.conf.d"
wp_conf_dir="${HOME}/.config/wireplumber/wireplumber.conf.d"
wp_script_dir="${HOME}/.local/share/wireplumber/scripts"

echo "==> Installing"
mkdir -pv "${pw_conf_dir}"
cp -fv speaker.pipewire.conf "${pw_conf_dir}/gpd-wm2-speaker.conf"
mkdir -pv "${pw_conf_dir}"
cp -fv speaker.wireplumber.conf "${wp_conf_dir}/gpd-wm2-speaker.conf"
mkdir -pv "${wp_script_dir}"
cp -fv speaker.wireplumber.lua "${wp_script_dir}/gpd-wm2-speaker.lua"

echo "==> Restarting systemd units"
if [[ -n "${DBUS_SESSION_BUS_ADDRESS}" && -n "${XDG_RUNTIME_DIR}" ]]; then
  systemctl restart --user pipewire.service pipewire-pulse.service wireplumber.service
else
  echo " :: Not an interactive session, skipping"
fi

echo "==> Done"
