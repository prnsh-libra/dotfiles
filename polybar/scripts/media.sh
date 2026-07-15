#!/usr/bin/env sh

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

TITLE_WIDTH=15
SLEEP_INTERVAL=0.1

player_args() {
  if playerctl --player=spotify status >/dev/null 2>&1; then
    printf '%s' '--player=spotify'
    return
  fi

  return 1
}

get_field() {
  field="$1"
  shift
  playerctl "$@" metadata --format "{{ ${field} }}" 2>/dev/null | head -n1
}

get_status() {
  playerctl "$@" status 2>/dev/null | head -n1
}

sanitize_text() {
  perl -CS -Mutf8 -pe "
    s/\x{2019}/'/g;
    s/\x{2018}/'/g;
    s/\x{201C}/\"/g;
    s/\x{201D}/\"/g;
    s/\x{2013}/-/g;
    s/\x{2014}/--/g;
    s/\x{2026}/.../g;
    s/â€™/'/g;
    s/â€˜/'/g;
    s/â€œ/\"/g;
    s/â€\x9d/\"/g;
    s/â€“/-/g;
    s/â€”/--/g;
    s/â€¦/.../g;
  " <<EOF
$1
EOF
}

char_len() {
  perl -CS -Mutf8 -e 'my $s = join("", <>); print length($s);' <<EOF
$1
EOF
}

pad_text() {
  text="$1"

  perl -CS -Mutf8 -e '
    my ($text, $width) = @ARGV;
    my $len = length($text // q{});

    if ($len == 0) {
      print " " x $width;
    } elsif ($len <= $width) {
      print $text . (" " x ($width - $len));
    } else {
      print substr($text . q{   }, 0, $width);
    }
  ' "$text" "$TITLE_WIDTH"
}

marquee() {
  text="$1"
  offset="$2"

  if [ -z "$text" ]; then
    printf '%-*s' "$TITLE_WIDTH" ""
    return
  fi

  len=$(char_len "$text")
  if [ "$len" -le "$TITLE_WIDTH" ]; then
    printf '%-*s' "$TITLE_WIDTH" "$text"
    return
  fi

  perl -CS -Mutf8 -e '
    my ($text, $offset, $width) = @ARGV;
    my $padded = $text . q{   } . $text;
    my $len = length($text);
    my $start = $offset % ($len + 3);
    print substr($padded, $start, $width);
  ' "$text" "$offset" "$TITLE_WIDTH"
}

render() {
  player="$(player_args)" || {
    printf '\n'
    return
  }

  if [ -n "$player" ]; then
    set -- "$player"
  else
    set --
  fi

  status="$(get_status "$@")"
  title="$(get_field title "$@")"
  title="$(sanitize_text "$title")"

  if [ -z "$title" ]; then
    printf '\n'
    return
  fi

  if [ "$status" = "Playing" ]; then
    title_text="$(marquee "$title" "$offset")"
    title_fmt='%{F#d0d0d0}'
  else
    title_text="$(pad_text "$title")"
    title_fmt='%{F#88d0d0d0}'
  fi

  prev='%{A1:playerctl --player=spotify previous:}%{F#88d0d0d0} %{T3}%{T-} %{F-}%{A}'
  middle_text="%{T3}󰎇%{T-} ${title_text}"
  toggle="%{A1:playerctl --player=spotify play-pause:}${title_fmt}${middle_text}%{F-}%{A}"
  next='%{A1:playerctl --player=spotify next:}%{F#88d0d0d0} %{T3}%{T-} %{F-}%{A}'

  printf ' %s %s %s \n' "$prev" "$toggle" "$next"
}

offset=0
while :; do
  render

  player="$(player_args)" || {
    sleep "$SLEEP_INTERVAL"
    continue
  }

  if [ -n "$player" ]; then
    set -- "$player"
  else
    set --
  fi

  status="$(get_status "$@")"
  title="$(get_field title "$@")"
  title="$(sanitize_text "$title")"

  if [ "$status" = "Playing" ] && [ -n "$title" ] && [ "$(char_len "$title")" -gt "$TITLE_WIDTH" ]; then
    offset=$((offset + 1))
  else
    offset=0
  fi

  sleep "$SLEEP_INTERVAL"
done
