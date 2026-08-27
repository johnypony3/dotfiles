#!/usr/bin/env python3
# Merges rather than overwrites: settings.json holds machine-specific keys and a GL_TOKEN that must survive.

import json
import sys
from pathlib import Path

MANAGED_BASH_HOOKS = [
    "~/.claude/hooks/git-confirm.sh",
    "~/.claude/hooks/guard-fs-deletes.sh",
]
HOOK_TIMEOUT = 10
ADHD_MARKETPLACE = "i-have-adhd"
ADHD_MARKETPLACE_SOURCE = {"source": {"source": "github", "repo": "ayghri/i-have-adhd"}}
ADHD_PLUGIN = "i-have-adhd@i-have-adhd"


def bash_matcher(pre_tool_use):
    for entry in pre_tool_use:
        if entry.get("matcher") == "Bash":
            return entry
    entry = {"matcher": "Bash", "hooks": []}
    pre_tool_use.append(entry)
    return entry


def ensure_hooks(settings):
    changed = False
    pre_tool_use = settings.setdefault("hooks", {}).setdefault("PreToolUse", [])
    entry = bash_matcher(pre_tool_use)
    existing = {hook.get("command") for hook in entry.setdefault("hooks", [])}
    for command in MANAGED_BASH_HOOKS:
        if command not in existing:
            entry["hooks"].append(
                {"type": "command", "command": command, "timeout": HOOK_TIMEOUT}
            )
            changed = True
    return changed


def ensure_adhd(settings):
    changed = False
    marketplaces = settings.setdefault("extraKnownMarketplaces", {})
    if marketplaces.get(ADHD_MARKETPLACE) != ADHD_MARKETPLACE_SOURCE:
        marketplaces[ADHD_MARKETPLACE] = ADHD_MARKETPLACE_SOURCE
        changed = True
    plugins = settings.setdefault("enabledPlugins", {})
    if plugins.get(ADHD_PLUGIN) is not True:
        plugins[ADHD_PLUGIN] = True
        changed = True
    return changed


def main():
    path = Path(sys.argv[1]).expanduser()
    settings = json.loads(path.read_text()) if path.exists() else {}
    hooks_changed = ensure_hooks(settings)
    adhd_changed = ensure_adhd(settings)
    if hooks_changed or adhd_changed:
        path.write_text(json.dumps(settings, indent=2) + "\n")
        print("CHANGED")
    else:
        print("UNCHANGED")


if __name__ == "__main__":
    main()
