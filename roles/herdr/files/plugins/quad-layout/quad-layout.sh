#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"

# jq -e fails on missing/null fields so a bad herdr response kills the script
# here instead of propagating the literal string "null" into later split calls.
pane_id() { jq -re '.result.pane.pane_id'; }

# Startup hooks re-run on every session restore/handoff, so guard against
# re-creating this tab when a snapshot already restored it. The tab-list check
# is split from the jq match so a failed herdr call aborts loudly instead of
# reading as "tab absent" and stacking a duplicate layout.
if [ "${HERDR_PLUGIN_EVENT:-}" = "startup" ]; then
  TABS=$("$HERDR" tab list)
  if echo "$TABS" | jq -e '.result.tabs[]? | select(.label == "quad-layout")' >/dev/null; then
    exit 0
  fi
fi

TAB_JSON=$("$HERDR" tab create --label quad-layout --focus)
COL0=$(echo "$TAB_JSON" | jq -re '.result.root_pane.pane_id')

# --ratio is the fraction the SOURCE (pre-split) pane keeps, opposite of
# tmux's -p (percentage of the NEW pane) - confirmed empirically on 0.8.2 via
# `pane edges` before/after a test split. Values below are 1 minus the tmux -p
# value at each step, chained against each split's own shrinking source width,
# same as the original script's sequential -p semantics.
COL1=$("$HERDR" pane split "$COL0" --direction right --ratio 0.17 --focus    | pane_id)
COL2=$("$HERDR" pane split "$COL1" --direction right --ratio 0.40 --no-focus | pane_id)
COL3=$("$HERDR" pane split "$COL2" --direction right --ratio 0.67 --no-focus | pane_id)

"$HERDR" pane split "$COL0" --direction down --ratio 0.50 --no-focus >/dev/null
GLANCES=$("$HERDR" pane split "$COL3" --direction down --ratio 0.50 --no-focus | pane_id)

"$HERDR" pane run "$GLANCES" glances
