#!/usr/bin/env sh

WEATHER_CACHE="/tmp/weather_cache"

get_code() {
  if [ -f "$WEATHER_CACHE" ]; then
    line=$(cat "$WEATHER_CACHE")
    if [ -n "$line" ]; then
      IFS='|' read -r code _rest <<EOF
$line
EOF
      echo "$code"
      return
    fi
  fi
  echo ""
}

bg_for_code() {
  code="$1"
  hour=$(date +%H)
  # time-of-day base
  if [ "$hour" -ge 6 ] && [ "$hour" -lt 12 ]; then
    base="#808fd0ff"  # morning light blue
  elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
    base="#8067b1ff"  # afternoon blue
  else
    base="#80407dd9"  # night dark blue
  fi

  case "$code" in
    119|122) echo "#808b8b8b";;         # cloudy gray
    143|248|260) echo "#806e7f8a";;      # fog gray-blue
    176|293|296|299|302|305|308|353|356|359|263|266) echo "#805a8cff";; # rain blue
    179|182|317|320|362|365) echo "#8079a7ff";; # sleet blue
    185|281|284|311|314) echo "#805a7bd9";; # freezing rain
    200|386|389) echo "#80f2cf5a";;      # thunder yellow
    227|230|323|326|329|332|335|338|368|371|392|395) echo "#80b5d8ff";; # snow blue
    350) echo "#80a0b9d9";;             # ice pellets
    *) echo "$base";;
  esac
}

icon_for_code() {
  code="$1"
  hour=$(date +%H)
  case "$code" in
    113) icon="";;
    116) icon="";;
    119|122) icon="";;
    143|248|260) icon="";;
    176|293|296|299|302|305|308|353|356|359|263|266) icon="";;
    179|182|317|320|362|365) icon="";;
    185|281|284|311|314) icon="";;
    200|386|389) icon="";;
    227|230|323|326|329|332|335|338|368|371|392|395) icon="";;
    350) icon="";;
    *) icon="";;
  esac
  if [ "$hour" -lt 6 ] || [ "$hour" -ge 19 ]; then
    case "$code" in
      113) icon="";;
      116) icon="";;
    esac
  fi
  echo "$icon"
}

code=$(get_code | tr -cd '0-9')
[ -n "$code" ] || code=113
bg=$(bg_for_code "$code")
icon=$(icon_for_code "$code")

printf "%%{T2}%%{F%s}%%{F-}%%{T-}%%{B%s}%%{T3}%s%%{T-}  %%{B-}" "$bg" "$bg" "$icon"
