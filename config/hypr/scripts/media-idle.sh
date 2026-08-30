#!/bin/bash

video=false

while true; do
  if [[ "$(playerctl status 2>/dev/null)" == "Playing" ]]; then
    url=$(playerctl metadata xesam:url 2>/dev/null)

    case "${url,,}" in
    *.mp4 | *.mkv | *.webm | *.avi | *.mov | *.m4v | *.flv | *.wmv | *.mpeg | *.mpg | *.ts | *.m2ts)
      if [[ "$video" == false ]]; then
        pkill -x hypridle
        video=true
      fi
      ;;
    *)
      video=false
      ;;
    esac
  else
    if [[ "$video" == true ]]; then
      hyprctl dispatch exec "hypridle"
      video=false
    fi
  fi

  sleep 2
done
