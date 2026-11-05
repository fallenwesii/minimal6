#!/usr/bin/env bash
# media-idle.sh - pause screen locking while a video is playing.
#
# One file, two roles:
#   supervisor (default) - keeps the polling worker alive, so a killed or
#                          crashed worker can never leave the session
#                          without a screen lock
#   worker (--worker)    - polls playerctl and stops/starts swayidle
#
# State files live in a per-user, mode-700 directory under /tmp. A directory
# avoids a world-writable, predictable marker that another local user could
# replace.

script=$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")
state_dir="/tmp/minimal6-${UID}"
if [[ ! -d "$state_dir" ]]; then
  (umask 077 && mkdir "$state_dir") 2>/dev/null || exit 1
fi
if [[ ! -O "$state_dir" || "$(stat -c '%a' "$state_dir" 2>/dev/null)" != 700 ]]; then
  exit 1
fi
pidfile="$state_dir/media-idle.pid"
caffeine_file="$state_dir/sway-caffeine"

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

is_local_video_player() {
  case "${1,,}" in
  vlc | mpv)
    return 0
    ;;
  esac
  return 1
}

# --- swayidle control --------------------------------------------------
swayidle_running() {
  local pid state
  for pid in $(pgrep -x swayidle 2>/dev/null); do
    state=$(ps -o state= -p "$pid" 2>/dev/null)
    [[ -n "$state" && "$state" != Z* ]] && return 0 # ignore zombies
  done
  return 1
}

start_swayidle() {
  swayidle_running && return
  swayidle -w \
    timeout 300 'swaymsg exec hyprlock' \
    timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
    before-sleep 'swaymsg exec hyprlock' &
}

kill_swayidle() {
  pkill -x swayidle 2>/dev/null || true
}

# --- player detection --------------------------------------------------
# Every call is capped with `timeout`: a stuck D-Bus reply must never wedge
# the loop, because a wedged loop cannot bring swayidle back.
video_playing() {
  local player status url players
  players=$(timeout 2 playerctl -l 2>/dev/null) || return 1
  while IFS= read -r player; do
    [[ -n "$player" ]] || continue
    is_local_video_player "$player" || continue
    status=$(timeout 2 playerctl -p "$player" status 2>/dev/null) || continue
    [[ "$status" == Playing ]] || continue
    url=$(timeout 2 playerctl -p "$player" metadata xesam:url 2>/dev/null) || continue
    is_video_url "$url" && return 0
  done <<<"$players"
  return 1
}

# --- worker ------------------------------------------------------------
cleanup_worker() {
  # If we are going away while no video is playing, restore swayidle so the
  # screen can still lock (the supervisor will respawn us either way).
  if [[ ! -f "$caffeine_file" ]] && ! video_playing && ! swayidle_running; then
    start_swayidle
  fi
  exit 0
}

worker() {
  trap cleanup_worker EXIT INT TERM
  while true; do
    if video_playing; then
      kill_swayidle
    else
      start_swayidle
    fi
    sleep 2
  done
}

# --- supervisor --------------------------------------------------------
supervisor() {
  # Single instance. Only trust a pidfile we own that points at another
  # copy of this script - stale pids (and pidfiles planted by other users
  # in /tmp) must not block a restart.
  if [[ -f "$pidfile" && -O "$pidfile" ]]; then
    old_pid=$(cat "$pidfile" 2>/dev/null)
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null &&
      tr '\0' ' ' <"/proc/$old_pid/cmdline" 2>/dev/null | grep -q "media-idle"; then
      exit 0
    fi
  fi
  rm -f "$pidfile" 2>/dev/null
  printf '%s\n' "$$" >"$pidfile" 2>/dev/null
  cleanup_supervisor() {
    # Do not leave a detached worker behind if the supervisor is stopped by
    # a session reload, logout, or a service manager.
    pkill -f "$script --worker" 2>/dev/null || true
    rm -f "$pidfile" 2>/dev/null
  }
  trap cleanup_supervisor EXIT
  trap 'exit 0' INT TERM

  while true; do
    if [[ -f "$caffeine_file" ]]; then
      pkill -f "$script --worker" 2>/dev/null # caffeine on: keep it down
    elif ! pgrep -f "$script --worker" >/dev/null 2>&1; then
      bash "$script" --worker &
    fi
    sleep 5
  done
}

if [[ "${1:-}" == "--worker" ]]; then
  worker
else
  supervisor
fi
