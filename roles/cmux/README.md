# cmux role

Installs and configures [cmux](https://github.com/manaflow-ai/cmux), a Ghostty-based macOS terminal built for AI coding agents. The `cmux` cask itself is installed by the `brew` role (common list, both profiles).

Not to be confused with `craigsc/cmux`, an unrelated git-worktree agent manager of the same name.

## Two config files, split by ownership

cmux deliberately splits configuration:

| File | Owns | Deployed from |
|---|---|---|
| `~/.config/cmux/cmux.json` | app behaviour, sidebar, notifications, panes, automation | `files/cmux.json` |
| `~/.config/ghostty/config` | terminal rendering: font, theme, cursor, scrollback | `files/ghostty.config` |

Anything visual about the terminal grid goes in the Ghostty file - cmux reads it but does not own it. Everything else goes in `cmux.json`. Putting a font in `cmux.json` silently does nothing.

`cmux reload-config` reloads both and refreshes terminals in place, with no app restart.

Both files are deployed with `backup: true`, so each run leaves a timestamped `.bak` next to any file it replaces. Ghostty is not installed separately on either machine, so `~/.config/ghostty/config` is effectively cmux-only; if Ghostty is ever installed, that file becomes shared and this role will own it.

## Settings chosen, and why

`cmux.json`:

- `app.confirmQuit: "dirty-only"` - only prompt on quit when a workspace reports unsaved or confirm-needed state. Upstream default is `always`, which nags on every Cmd+Q.
- `paneBorderColor: "#444444"` / `activePaneBorderColor: "#00AFFF"` - the hex equivalents of xterm colours 238 and 39, which `roles/tmux/files/tmux.conf` already uses for `pane-border-style` and `pane-active-border-style`. Keeps the active-pane cue identical across tmux and cmux.
- `terminal.textBoxDefaultSubmitAction: "claude"` - the TextBox submit button launches Claude Code rather than plain text entry.
- `diffViewer.defaultLayout: "split"` - side-by-side diffs. Upstream default is `unified`; these are wide displays.
- `sidebar.showAgentActivity: true` with both indicators `leading` - spinner and unread badge on the same side. These match upstream defaults and are set explicitly so a future upstream change does not move them.

`ghostty.config`:

- `font-family = JetBrainsMono Nerd Font Mono`, `font-size = 12` - matches the iTerm2 profile (`JetBrainsMonoNFM-Regular 12`) so Nerd Font glyphs render the same in both terminals. The `Mono` variant is the fixed-advance one; plain `JetBrainsMono Nerd Font` and the `Propo` variant are not.
- `cursor-style = block`, `mouse-hide-while-typing = true`, `copy-on-select = clipboard`, 2px padding - ordinary terminal ergonomics.
- No `theme` is set, so cmux follows the system light/dark appearance.

## Deliberately left at upstream defaults

Two opt-in features look attractive but are off, because upstream ships them off on purpose and both have real costs:

- `terminal.agentHibernation` - kills idle background agent processes to reclaim RAM, resuming them from saved session on tab visit. An agent blocked on a slow build reads as idle, so this can interrupt real work. Enable per-machine with `cmux agent-hibernation on` if RAM pressure justifies it.
- `automation.workspaceAutoNaming` - AI-summarises conversations into workspace and tab names, re-running as topics shift. Costs agent tokens on every topic change.

## Quad layout

`files/cmux-quad-layout.sh` reproduces the tmux quad layout from `roles/tmux/files/quad-layout.sh`: four columns, the first and last split horizontally, `glances` running bottom-right, focus landing on column 2.

It is deployed to `~/.config/cmux/quad-layout.sh` and **must be run from inside a cmux terminal**:

```sh
~/.config/cmux/quad-layout.sh
```

cmux rejects CLI connections from processes it did not start (`Access denied - only processes started inside cmux can connect`), so the script probes with `cmux ping` and exits with a clear error when it cannot reach the socket.

Unlike tmux's `bind Q`, there is no keybinding: `shortcuts.bindings` in `cmux.json` rebinds cmux's own built-in actions and cannot launch an arbitrary shell command.

`cmux new-split` takes a direction only, with no percentage sizing, so columns are evenly divided rather than reproducing the tmux script's 83/60/33 percentage splits.
