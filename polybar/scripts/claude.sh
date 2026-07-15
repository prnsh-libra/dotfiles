#!/usr/bin/env sh

# Claude Code status pill for polybar.
#
# State is written by ~/.claude/hooks/claude-notify.sh, one file per session,
# each line formatted as:   <state>\t<bspwm-desktop-id>
#   state = working | waiting | done   (working is hidden)
#
# Shown as an icon-only robot:
#   waiting -> animated amber robot (Claude needs your input)
#   done    -> static green robot   (Claude finished)
# The module collapses (prints empty) when nothing needs attention.
# Left-click jumps to the bspwm desktop that session is running on.

DIR="${XDG_RUNTIME_DIR:-/tmp}/claude-polybar"
SELF="$HOME/.config/polybar/scripts/claude.sh"
TAB=$(printf '\t')

# --- click handlers -------------------------------------------------------
# goto <desktop-id> <session-file>: focus that desktop. Does NOT dismiss the
# pill — it clears itself when the session moves on (next prompt / session end).
if [ "$1" = "goto" ]; then
  [ "$2" != "-" ] && [ -n "$2" ] && command -v bspc >/dev/null 2>&1 && \
    bspc desktop -f "$2" 2>/dev/null
  exit 0
fi
if [ "$1" = "clear" ]; then
  rm -f "$DIR"/* 2>/dev/null
  exit 0
fi

# --- appearance -----------------------------------------------------------
# Animation frames for "waiting" (cycled to look alive).
W0='󱚟'; W1='󱚡'; W2='󱚣'
DONE_ICON='󰚩'
AMBER='#e5a458'
GREEN='#8ec07c'

frame=0
render() {
  state=""; sid=""; desk="-"

  if [ -d "$DIR" ]; then
    for f in "$DIR"/*; do
      [ -e "$f" ] || continue
      # Reap stale files from crashed sessions (older than 12h).
      if [ -n "$(find "$f" -mmin +720 2>/dev/null)" ]; then
        rm -f "$f"
        continue
      fi
      line=$(head -n1 "$f" 2>/dev/null)
      st=${line%%"$TAB"*}
      dk=${line#*"$TAB"}
      [ "$dk" = "$line" ] && dk="-"      # no tab -> no desktop stored
      [ -z "$dk" ] && dk="-"
      case "$st" in
        waiting) state="waiting"; sid=$(basename "$f"); desk="$dk"; break ;;
        done)    [ "$state" != "waiting" ] && { state="done"; sid=$(basename "$f"); desk="$dk"; } ;;
      esac
    done
  fi

  case "$state" in
    waiting)
      case $((frame % 3)) in
        0) icon="$W0" ;;
        1) icon="$W1" ;;
        2) icon="$W2" ;;
      esac
      printf '  %%{A1:%s goto %s %s:}%%{F%s}%%{T3}%s%%{T-}%%{F-}%%{A}  \n' \
        "$SELF" "$desk" "$sid" "$AMBER" "$icon"
      ;;
    done)
      printf '  %%{A1:%s goto %s %s:}%%{F%s}%%{T3}%s%%{T-}%%{F-}%%{A}  \n' \
        "$SELF" "$desk" "$sid" "$GREEN" "$DONE_ICON"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

while :; do
  render
  frame=$((frame + 1))
  sleep 0.4
done
