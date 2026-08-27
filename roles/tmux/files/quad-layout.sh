#!/usr/bin/env bash
set -euo pipefail

# pane indices shift on every split, so target stable pane IDs instead
COL0=$(tmux display-message -p '#{pane_id}')
COL1=$(tmux split-window -h -p 83 -P -F '#{pane_id}')
COL2=$(tmux split-window -h -p 60 -t "$COL1" -P -F '#{pane_id}')
COL3=$(tmux split-window -h -p 33 -t "$COL2" -P -F '#{pane_id}')

tmux split-window -v -p 50 -t "$COL0"
GLANCES=$(tmux split-window -v -p 50 -t "$COL3" -P -F '#{pane_id}')

tmux send-keys -t "$GLANCES" 'glances' Enter
tmux select-pane -t "$COL1"
