#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

echo "$input" > /tmp/git-confirm-debug.json

cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Allows flag-with-value forms so `git -C /path commit` cannot slip past.
git_subcmd_re='(^|[[:space:];|&(])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-][^[:space:]]*)?)*[[:space:]]+(commit|push)([[:space:]]|$)'

if ! echo "$cmd" | grep -qE "$git_subcmd_re"; then
  exit 0
fi

action="commit"
if echo "$cmd" | grep -qE '(^|[[:space:];|&(])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-][^[:space:]]*)?)*[[:space:]]+push([[:space:]]|$)'; then
  action="push"
fi

transcript_file=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  transcript_file="$transcript_path"
elif [ -n "$session_id" ]; then
  search_dirs=("$HOME/.claude/projects")
  if [ -n "${CLAUDE_PROJECTS_DIR:-}" ]; then
    search_dirs=("$CLAUDE_PROJECTS_DIR" "${search_dirs[@]}")
  fi
  for base in "${search_dirs[@]}"; do
    for d in "$base"/*/; do
      f="${d}${session_id}.jsonl"
      if [ -f "$f" ]; then
        transcript_file="$f"
        break 2
      fi
    done
  done
fi

# isSidechain entries are subagent turns, whose "user" message is written by the
# main agent. Excluding them stops the model authorizing itself via a task prompt.
last_user_text=""
if [ -n "$transcript_file" ]; then
  last_user_text=$(tac "$transcript_file" 2>/dev/null | jq -r '
    select(.type=="user")
    | select((.isMeta // false) == false)
    | select((.isSidechain // false) == false)
    | (.message.content) as $c
    | (if ($c|type)=="string" then $c
       elif ($c|type)=="array" then ($c | map(select(.type=="text") | .text) | join("\n"))
       else "" end)
    | select(. != null and (gsub("\\s";"") | length) > 0)
  ' 2>/dev/null | head -1 || true)
fi

normalized=$(echo "$last_user_text" | tr '[:upper:]' '[:lower:]')

authorized=0
case "$action" in
  push)
    if echo "$normalized" | grep -qE '(^|[^a-z])(push|force[ -]?push)([^a-z]|$)'; then
      authorized=1
    fi
    ;;
  commit)
    if echo "$normalized" | grep -qE '(^|[^a-z])commit([^a-z]|$)'; then
      authorized=1
    fi
    ;;
esac

if [ "$authorized" -eq 1 ]; then
  exit 0
fi

# Deny, not ask: permissions.defaultMode=auto lets the classifier resolve "ask"
# on its own, which is how unauthorized commits got through before.
reason="BLOCKED: 'git ${action}' requires the literal word '${action}' in the user's most recent message. Approvals never chain from earlier messages, and there is no override token for git by design. Stop and ask the user to say '${action}'. (Enforced by ~/.claude/hooks/git-confirm.sh)"

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
