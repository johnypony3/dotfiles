#!/usr/bin/env bash
# PreToolUse hook (Bash): require human confirmation for file deletions that
# target locations OUTSIDE the session working directory.
#
# Allowed silently (no prompt):
#   - deletes whose every target resolves under the session cwd
#   - deletes whose every target resolves under /tmp (and its macOS canonical
#     /private/tmp) -- the explicit scratch exception
# Confirmation required (permissionDecision "ask"):
#   - any target outside cwd and outside /tmp
#   - any delete we cannot statically prove is in-bounds (globs, $VARS,
#     command substitution, `cd` that moves the working dir, etc.)
#
# Delete commands inspected: rm, rmdir, unlink, shred, truncate -s 0,
#   find ... -delete / -exec rm, git clean -f, trash/trash-put.
#
# Fail-safe bias: deletion is irreversible, so anything not provably in-bounds
# becomes a prompt. Worst case is an extra confirmation; never a silent
# out-of-bounds delete.
set -euo pipefail

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command_text=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

# --- does this command delete anything? --------------------------------------
delete_pattern='(^|[[:space:]]|/|&&|\|\||;)(rm|rmdir|unlink|shred|trash|trash-put)([[:space:]]|$)'
find_delete_pattern='\bfind\b.*(-delete([[:space:]]|$)|-exec[[:space:]]+rm\b|-execdir[[:space:]]+rm\b)'
gitclean_pattern='\bgit[[:space:]]+clean\b.*(-[a-zA-Z]*f|--force)'
truncate_pattern='\btruncate\b.*-s[[:space:]=]*0([[:space:]]|$|[bkKMG])'

is_delete=0
printf '%s' "$command_text" | grep -qE "$delete_pattern"       && is_delete=1
printf '%s' "$command_text" | grep -qE "$find_delete_pattern"  && is_delete=1
printf '%s' "$command_text" | grep -qE "$gitclean_pattern"     && is_delete=1
printf '%s' "$command_text" | grep -qE "$truncate_pattern"     && is_delete=1
[ "$is_delete" -eq 1 ] || exit 0

# --- decide whether to ask ---------------------------------------------------
ask_reason=""
need_ask=0
ask() { need_ask=1; [ -z "$ask_reason" ] && ask_reason="$1"; }

# Constructs we cannot resolve statically -> always confirm.
if printf '%s' "$command_text" | grep -qE '\$\(|`|\$\{?[A-Za-z_]'; then
  ask "Delete command contains a variable or command substitution whose target cannot be verified statically."
fi
# A `cd` (or pushd) before the delete changes what relative paths mean.
if printf '%s' "$command_text" | grep -qE '(^|[[:space:]]|&&|;|\|\|)(cd|pushd)([[:space:]]|$)'; then
  ask "Delete command changes the working directory (cd/pushd), so relative targets cannot be bounded to the session cwd."
fi
# find / git clean operate on trees relative to a starting path; treat as risky
# unless clearly bounded. git clean always acts on the repo, which may sit
# anywhere -> confirm. find we confirm unless its start path resolves in-bounds.
if printf '%s' "$command_text" | grep -qE "$gitclean_pattern"; then
  ask "git clean -f permanently removes untracked files from the repository working tree; confirm the scope."
fi

# Canonicalise a directory prefix without requiring the path to exist.
canon_prefix() {
  # $1 = absolute path; print a normalised form (resolve .. and . segments).
  printf '%s' "$1" | awk -F/ '{
    n=0; for (i=1;i<=NF;i++){ s=$i;
      if (s=="."||s=="") continue;
      if (s==".."){ if(n>0) n--; continue }
      stack[++n]=s }
    out="/"; for(i=1;i<=n;i++){ out=out stack[i]; if(i<n) out=out"/" }
    print out }'
}

cwd_canon=$(canon_prefix "$cwd")
home_canon=$(canon_prefix "${HOME:-/nonexistent-home}")

# Is an absolute path within an allowed root (cwd or /tmp)?
in_bounds() {
  local p="$1" c
  c=$(canon_prefix "$p")
  case "$c/" in
    "$cwd_canon"/*|"$cwd_canon"/) return 0 ;;
    /tmp/*|/tmp/|/private/tmp/*|/private/tmp/) return 0 ;;
  esac
  return 1
}

# Extract candidate path operands and bound-check them. CRITICAL: only inspect
# segments that actually contain a delete verb -- a compound command may join a
# delete with unrelated siblings (e.g. `aws ... --query 'R[0]' ; rm /tmp/x`),
# and tokens from the non-delete sibling must not be mistaken for delete
# targets. Split on shell separators, then process only delete-bearing segments.
seg_has_delete() {
  printf '%s' "$1" | grep -qE "$delete_pattern" && return 0
  printf '%s' "$1" | grep -qE "$find_delete_pattern" && return 0
  printf '%s' "$1" | grep -qE "$truncate_pattern" && return 0
  return 1
}

if [ "$need_ask" -eq 0 ]; then
  while IFS= read -r segment; do
    seg_has_delete "$segment" || continue
    # Strip leading whitespace and any leading env-assignment prefix.
    cleaned=$(printf '%s' "$segment" \
      | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//')
    for tok in $cleaned; do
      case "$tok" in
        rm|rmdir|unlink|shred|trash|trash-put|find|git|clean|truncate|sudo|-*|\;|'{}'|'&&'|'||'|'|') continue ;;
        *=*) continue ;;                       # stray key=value (e.g. -s=0 split)
      esac
      # Expand ~ to home.
      case "$tok" in
        "~") tok="$home_canon" ;;
        "~/"*) tok="$home_canon/${tok#~/}" ;;
      esac
      # Resolve relative tokens against cwd.
      case "$tok" in
        /*) abs="$tok" ;;
        *)  abs="$cwd_canon/$tok" ;;
      esac
      # Globs/braces can match paths we cannot enumerate -> confirm.
      case "$tok" in
        *\**|*\?*|*\[*|*\{*) ask "Delete target '$tok' uses a glob/brace whose matches cannot be bounded to the session cwd."; break 2 ;;
      esac
      if ! in_bounds "$abs"; then
        ask "Delete target resolves outside the session working directory and outside /tmp: $tok"
        break 2
      fi
    done
  done <<EOF
$(printf '%s' "$command_text" | tr ';&|\n' '\n')
EOF
fi

# --- emit decision -----------------------------------------------------------
# Out-of-bounds (or unprovable) deletes are hard-denied by default. An explicit
# human override downgrades the deny to a confirmation prompt. Override signals
# (either accepted):
#   * env-var prefix:  CLAUDE_RM_OVERRIDE=1 rm /etc/hosts
#   * inline marker:   rm /etc/hosts   # rm-override
if [ "$need_ask" -eq 1 ]; then
  override=0
  printf '%s' "$command_text" | grep -qE '(^|[[:space:]])CLAUDE_RM_OVERRIDE=1([[:space:]]|$)' && override=1
  printf '%s' "$command_text" | grep -qE '#[[:space:]]*rm-override' && override=1

  if [ "$override" -eq 1 ]; then
    jq -nc --arg r "Human override detected — downgraded from block to confirmation. $ask_reason Approve only if you intend to delete outside the session working directory." '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: $r
      }
    }'
  else
    jq -nc --arg r "Blocked: $ask_reason Policy requires human review and approval before deleting outside the session working directory (the /tmp scratch area is exempt). To proceed, re-run with the prefix 'CLAUDE_RM_OVERRIDE=1' or append '# rm-override' to the command." '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $r
      }
    }'
  fi
fi
# In-bounds deletes (under cwd or /tmp): stay silent and defer to the normal
# permission flow -- we deliberately do NOT auto-allow, per the chosen policy.
exit 0
