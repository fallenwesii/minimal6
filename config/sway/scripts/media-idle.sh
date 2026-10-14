#!/usr/bin/env bash

pidfile="/tmp/media-idle.pid"

# Single instance: exit if another copy is alive (stale pidfiles are ignored)
if [[ -f "$pidfile" ]]; then
  old_pid=$(cat "$pidfile" 2>/dev/null)
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ >"$pidfile"
trap 'rm -f "$pidfile"' EXIT

swayidle_running() {
  pgrep -x swayidle >/dev/null
}

kill_swayidle() {
  pkill -x swayidle 2>/dev/null || true
}

start_swayidle() {
  swayidle_running && return
  swayidle -w \
    timeout 300 'swaymsg exec hyprlock' \
    timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
    before-sleep 'swaymsg exec hyprlock' &
}

is_video_url() {
  local url="${1,,}"
  url="${url%%[?#]*}" # strip query string / fragment
  url="${url#file://}"
  case "$url" in
  *.mp4 | *.mkv | *.webm | *.avi | *.mov | *.m4v | *.flv | *.wmv | *.mpeg | *.mpg | *.ts | *.m2ts)
    return 0
    ;;
  esac
  return 1
}

while true; do
  playing_video=false
  if [[ "$(playerctl status 2>/dev/null)" == "Playing" ]]; then
    url=$(playerctl metadata xesam:url 2>/dev/null)
    is_video_url "$url" && playing_video=true
  fi

  # Enforce the invariant every cycle instead of tracking a flag:
  # swayidle must be absent during video, present otherwise.
  if $playing_video; then
    kill_swayidle
  else
    start_swayidle
  fi

  sleep 2
done
