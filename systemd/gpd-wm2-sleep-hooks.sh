#!/usr/bin/env bash
set -eo pipefail

## aplay -l -> card number
alsa_card="1"
## amixer -c 1 scontrols -> master channel with a mute switch
alsa_control="Master"
alsa_mute_state="/run/gpd-wm2-sleep-hooks-muted"

alsa-get() {
  amixer -c "${alsa_card}" sget "${alsa_control}"
}

alsa-set() {
  amixer -c "${alsa_card}" sset "${alsa_control}" "${1}" >/dev/null
}

if [[ ${1} == "sleep" ]]; then
  if alsa-get | grep -q '\[on\]'; then
    echo "sleep: muting"
    alsa-set mute
    touch "${alsa_mute_state}"
  else
    echo "sleep: was muted"
  fi
  exit 0
fi

if [[ ${1} == "wake" ]]; then
  if [[ -e "${alsa_mute_state}" ]]; then
    echo "wake: needs unmute"
    rm -f "${alsa_mute_state}"
    sleep 2
    echo "wake: unmuting"
    alsa-set unmute
  else
    echo "wake: nothing to do"
  fi
  exit 0
fi

echo "Unknown command '${1}'"
exit 1
