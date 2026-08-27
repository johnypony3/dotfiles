#!/usr/bin/env bash
set -euo pipefail

CMUX="${CMUX_BIN:-$(command -v cmux || echo /opt/homebrew/bin/cmux)}"

if ! "$CMUX" ping >/dev/null 2>&1; then
  echo "run this from inside a cmux terminal: cmux only accepts CLI connections from processes it started" >&2
  exit 1
fi

# new-split prints "OK surface:N workspace:N"; the surface ref is the handle we chain from.
# Omitting --surface targets this script's own pane, so the first column needs no ref.
split() {
  if [ -n "${2:-}" ]; then
    "$CMUX" new-split "$1" --surface "$2" --focus false
  else
    "$CMUX" new-split "$1" --focus false
  fi | grep -oE 'surface:[0-9]+' | head -1
}

COL1=$(split right)
COL2=$(split right "$COL1")
COL3=$(split right "$COL2")

split down >/dev/null
GLANCES=$(split down "$COL3")

"$CMUX" send --surface "$GLANCES" 'glances\n'
"$CMUX" focus-panel --panel "$COL1"
