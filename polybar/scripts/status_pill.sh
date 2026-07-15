#!/usr/bin/env sh

battery_pct() {
  for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] || continue
    cat "$b/capacity"
    return 0
  done
  echo "n/a"
}

battery_state() {
  for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/status" ] || continue
    cat "$b/status"
    return 0
  done
  echo "Unknown"
}

volume_pct() {
  if command -v wpctl >/dev/null 2>&1; then
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{v=$2*100; printf("%.0f", v)}')
    [ -n "$vol" ] && echo "$vol" || echo "0"
    return
  fi
  echo "0"
}

volume_muted() {
  if command -v wpctl >/dev/null 2>&1; then
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q "\[MUTED\]"
    return $?
  fi
  return 1
}

wifi_name() {
  if command -v iwgetid >/dev/null 2>&1; then
    ssid=$(iwgetid -r 2>/dev/null)
    [ -n "$ssid" ] && echo "$ssid" && return
  fi
  if command -v nmcli >/dev/null 2>&1; then
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes" {print $2; exit}')
    [ -n "$ssid" ] && echo "$ssid" && return
  fi
  echo "Offline"
}

wifi_strength() {
  if [ -r /proc/net/wireless ]; then
    iface=$(awk 'NR==3 {gsub(":", "", $1); print $1}' /proc/net/wireless)
    if [ -n "$iface" ]; then
      link=$(awk 'NR==3 {print $3}' /proc/net/wireless | tr -d '.')
      # link is typically 0-70
      if [ "$link" -le 0 ]; then echo 0; return; fi
      if [ "$link" -le 17 ]; then echo 1; return; fi
      if [ "$link" -le 35 ]; then echo 2; return; fi
      if [ "$link" -le 52 ]; then echo 3; return; fi
      echo 4
      return
    fi
  fi
  echo 0
}

bt_state() {
  if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo ""
    return
  fi
  if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    if bluetoothctl info 2>/dev/null | grep -q "Connected: yes"; then
      echo "on"
    else
      echo ""
    fi
  else
    echo ""
  fi
}

render() {
  bat=$(battery_pct)
  state=$(battery_state)
  vol=$(volume_pct)
  bt=$(bt_state)
  wifi=$(wifi_name)

  bat_icon="%{T3}%{T-}"
  if [ "$bat" != "n/a" ]; then
    if [ "$bat" -le 10 ]; then bat_icon="%{T3}%{T-}"
    elif [ "$bat" -le 25 ]; then bat_icon="%{T3}%{T-}"
    elif [ "$bat" -le 50 ]; then bat_icon="%{T3}%{T-}"
    elif [ "$bat" -le 80 ]; then bat_icon="%{T3}%{T-}"
    else bat_icon="%{T3}%{T-}"
    fi
  fi

  if [ "$state" = "Charging" ]; then
    step=$(( $(date +%s) % 5 ))
    case "$step" in
      0) bat_icon="%{T3}%{T-}";;
      1) bat_icon="%{T3}%{T-}";;
      2) bat_icon="%{T3}%{T-}";;
      3) bat_icon="%{T3}%{T-}";;
      4) bat_icon="%{T3}%{T-}";;
    esac
  fi

  case "$state" in
    Charging) bat_label="${bat_icon} ${bat}%+";;
    Full) bat_label="${bat_icon} ${bat}%";;
    Discharging) bat_label="${bat_icon} ${bat}%";;
    *) bat_label="${bat_icon} ${bat}%";;
  esac

  vol_icon="%{T3}%{T-}"
  if volume_muted; then
    vol_icon="%{T3}%{T-}"
  else
    if [ "$vol" -le 30 ]; then vol_icon="%{T3}%{T-}"
    elif [ "$vol" -le 60 ]; then vol_icon="%{T3}%{T-}"
    else vol_icon="%{T3}%{T-}"
    fi
  fi

  vol_segment="${vol_icon} ${vol}%"
  if volume_muted; then
    vol_segment="%{F#80d0d0d0}${vol_segment}%{F-}"
  fi

  wifi=$(wifi_name)
  strength=$(wifi_strength)
  case "$strength" in
    4) wifi_icon="%{T3}󰤨%{T-}";;
    3) wifi_icon="%{T3}󰤥%{T-}";;
    2) wifi_icon="%{T3}󰤢%{T-}";;
    1) wifi_icon="%{T3}󰤟%{T-}";;
    *) wifi_icon="%{T3}󰤭%{T-}";;
  esac
  [ "$wifi" = "off" ] && wifi_icon="%{T3}󰤭%{T-}"

  parts="  ${bat_label}  ${vol_segment}"
  if [ -n "$bt" ]; then
    parts="$parts  %{T3}%{T-} ${bt}"
  fi
  parts="$parts  ${wifi_icon} ${wifi}  "

  printf "%s\n" "$parts"
}

sub_pid=""
if command -v pw-mon >/dev/null 2>&1; then
  exec 3< <(pw-mon 2>/dev/null)
  sub_pid=$!
fi

trap '[ -n "$sub_pid" ] && kill "$sub_pid" 2>/dev/null' INT TERM EXIT

last_tick=0
render
while :; do
  if [ -n "$sub_pid" ] && read -r -t 0.2 -u 3 _line; then
    render
  fi
  now=$(date +%s)
  if [ $((now - last_tick)) -ge 1 ]; then
    render
    last_tick=$now
  fi
  sleep 0.1
 done
