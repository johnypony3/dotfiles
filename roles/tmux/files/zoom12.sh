#!/usr/bin/env bash
set -euo pipefail

WIN=$(tmux display-message -p '#{window_id}')
CUR=$(tmux display-message -p '#{pane_id}')
STATE=$(tmux show-window-options -v -t "$WIN" @zoom_mid 2>/dev/null || true)

if [ -n "$STATE" ]; then
  for entry in $STATE; do
    tmux resize-pane -t "${entry%%:*}" -x "${entry##*:}"
  done
  tmux set-window-option -t "$WIN" -u @zoom_mid
  exit 0
fi

# middle columns are identified by geometry, not index, so renumbering can't break this
LEFTS=$(tmux list-panes -t "$WIN" -F '#{pane_left}' | sort -n -u)
if [ "$(echo "$LEFTS" | wc -l | tr -d ' ')" -ne 4 ]; then
  tmux resize-pane -Z
  exit 0
fi

CURLEFT=$(tmux display-message -p '#{pane_left}')
L0=$(echo "$LEFTS" | sed -n '1p')
L1=$(echo "$LEFTS" | sed -n '2p')
L2=$(echo "$LEFTS" | sed -n '3p')
L3=$(echo "$LEFTS" | sed -n '4p')

if [ "$CURLEFT" = "$L1" ]; then
  OTHER="$L2"
elif [ "$CURLEFT" = "$L2" ]; then
  OTHER="$L1"
else
  tmux resize-pane -Z
  exit 0
fi

pane_at() {
  tmux list-panes -t "$WIN" -F '#{pane_left} #{pane_id}' | awk -v l="$1" '$1==l {print $2; exit}'
}
width_at() {
  tmux list-panes -t "$WIN" -F '#{pane_left} #{pane_width}' | awk -v l="$1" '$1==l {print $2; exit}'
}

SIBLING=$(pane_at "$OTHER")
OUT_A=$(pane_at "$L0")
OUT_B=$(pane_at "$L3")
CURW=$(tmux display-message -p '#{pane_width}')
SIBW=$(width_at "$OTHER")
OUT_AW=$(width_at "$L0")
OUT_BW=$(width_at "$L3")

tmux set-window-option -t "$WIN" @zoom_mid "$CUR:$CURW $SIBLING:$SIBW $OUT_A:$OUT_AW $OUT_B:$OUT_BW"

# pin the outer columns so the freed width goes to the zoomed pane, not to them
tmux resize-pane -t "$SIBLING" -x 1
tmux resize-pane -t "$OUT_A" -x "$OUT_AW"
tmux resize-pane -t "$OUT_B" -x "$OUT_BW"
tmux resize-pane -t "$CUR" -x $((CURW + SIBW - 1))
