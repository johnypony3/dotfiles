#!/usr/bin/env bash
set -euo pipefail

tmux split-window -h -p 83
tmux split-window -h -p 60 -t 1
tmux split-window -h -p 33 -t 2
tmux split-window -v -p 50 -t 0
tmux split-window -v -p 50 -t 3
tmux send-keys -t 5 'glances' Enter
tmux select-pane -t 0
