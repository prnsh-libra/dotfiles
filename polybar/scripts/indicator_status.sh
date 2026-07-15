#!/usr/bin/env sh

# Default gray (50% alpha)
color="#802a2a2a"

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

flash_if_high_volume() {
  vol="$1"
  [ -n "$vol" ] || return 1
  if [ "$vol" -ge 75 ]; then
    now=$(date +%s)
    stamp_file="/tmp/polybar-vol-flash"
    last=""
    if [ -r "$stamp_file" ]; then
      last=$(cat "$stamp_file" 2>/dev/null)
    fi
    if [ "$last" != "$now" ]; then
      echo "$now" > "$stamp_file"
    fi
    # Flash for 2 seconds after detection
    if [ -n "$last" ] && [ $((now - last)) -le 2 ]; then
      return 0
    fi
    if [ -z "$last" ]; then
      return 0
    fi
  fi
  return 1
}

bat=$(battery_pct)
state=$(battery_state)
vol=$(volume_pct)

if flash_if_high_volume "$vol"; then
  color="#80ff2a2a"
else
  if [ "$bat" != "n/a" ]; then
    if [ "$bat" -lt 20 ]; then
      color="#80d94a4a"
    else
      case "$state" in
        Full) color="#807ad97a";;
        Charging) color="#807ad97a";;
        Discharging) color="#80f3b65c";;
        *) color="#802a2a2a";;
      esac
    fi
  fi
fi

printf "%%{T2}%%{F%s}%%{F-}%%{T-}%%{B%s}%%{T3}%%{T-}  %%{B-}" "$color" "$color"
