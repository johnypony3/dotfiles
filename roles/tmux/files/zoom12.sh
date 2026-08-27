#!/usr/bin/env bash
set -euo pipefail

WIN=$(tmux display-message -p '#{window_id}')
CUR=$(tmux display-message -p '#{pane_index}')
STATE=$(tmux show-window-option -qv -t "$WIN" @zoomed12)

if [ -n "$STATE" ]; then
  W1=$(tmux show-window-option -qv -t "$WIN" @pw1)
  W2=$(tmux show-window-option -qv -t "$WIN" @pw2)
  tmux resize-pane -t 1 -x "$W1"
  tmux resize-pane -t 2 -x "$W2"
  tmux set-window-option -t "$WIN" -u @zoomed12
elif [ "$CUR" = "1" ] || [ "$CUR" = "2" ]; then
  W1=$(tmux display-message -p -t 1 '#{pane_width}')
  W2=$(tmux display-message -p -t 2 '#{pane_width}')
  tmux set-window-option -t "$WIN" @pw1 "$W1"
  tmux set-window-option -t "$WIN" @pw2 "$W2"
  if [ "$CUR" = "1" ]; then
    tmux resize-pane -t 2 -x 1
  else
    tmux resize-pane -t 1 -x 1
  fi
  tmux set-window-option -t "$WIN" @zoomed12 "$CUR"
else
  tmux resize-pane -Z
fi
