# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Standalone Ansible config for provisioning Edward's Mac laptops — both personal (`edward-laptop`) and work (`LNEJ217RV7F9Q`) — via System Settings, Homebrew, dotfiles, and app prefs. Everything targets `localhost` with `connection: local` — there is no remote inventory. `PLAN.md` is the original design doc; treat it as background, not a current task list (most of it is already built, and it predates the personal/work split).

A sibling repo, `../skynet`, is an Ansible + Kubernetes homelab for a Linux NUC and is the pattern this repo followed (e.g. the NAS-mount LaunchAgent approach). Do not port work back into skynet — this repo owns all Mac-specific config now.

## Personal vs. work profile

One playbook, one role list, run unmodified on either laptop — `playbooks/mac.yml` picks a `profile` (`personal`/`work`) by matching `ansible_facts['nodename']` against the `host_profiles` map defined inline in the play's `vars:`. An unrecognized hostname fails the play immediately (undefined dict key) rather than silently defaulting to a profile — add new machines to that map explicitly.

The chosen profile drives two things:
- A `pre_tasks` step `include_vars`-loads `group_vars/{{ profile }}.yml`, which sets `*_extra` lists (`brew_taps_extra`, `brew_formulae_extra`, `brew_casks_extra`, `brew_vscode_extensions_extra`) and `kubeconfig_path` (personal-only; empty on work, and `zshrc.j2` conditionally omits `export KUBECONFIG` when unset). Note `group_vars/` here is **not** Ansible's automatic group_vars mechanism — there are no inventory groups, so these are loaded manually by the explicit path in `pre_tasks`. Don't expect them to auto-load.
- The `shares` role entry in `mac.yml` has `when: profile == 'personal'` — NAS mounts never run on the work laptop.

`roles/brew/defaults/main.yml` holds only packages confirmed common to both laptops (verified against a real `brew bundle dump` on the work laptop, not guessed); role tasks install `brew_taps + brew_taps_extra` etc. When adding a package, decide personal/work/common first, then add it to the right file — don't add directly to the base list unless it's genuinely needed on both.

## Commands

```bash
ansible-playbook playbooks/mac.yml                 # run everything — profile (personal/work) auto-detected from hostname, no flag needed
ansible-playbook playbooks/mac.yml --tags shares    # not currently tagged — use --limit/-vvv or edit mac.yml's role list to scope a run
ansible-playbook playbooks/mac.yml --check          # dry run (many tasks are commands/shell, so --check coverage is partial)
ansible-lint                                        # lint (installed via the brew role itself)
yamllint .                                          # yaml lint (also installed via brew role)
```

To run a single role, comment out the others in `playbooks/mac.yml`'s `roles:` list, or copy the playbook and trim it — roles aren't tagged individually.

`ansible.cfg` pins `interpreter_python` to `/opt/homebrew/bin/python3` (Apple Silicon Homebrew path) — this assumes an arm64 Mac with Homebrew already at the default prefix.

## Architecture

Each `roles/<name>/` is independent and mapped 1:1 to a config surface, applied in this order from `playbooks/mac.yml`: `brew → keyboard → iterm2 → btt → shares → tmux → zsh → neovim`. Order matters where a later role depends on a tool an earlier role installs (e.g. `brew` installs `tmux`/`fzf` casks/formulae before `tmux`/`zsh` deploy their configs — note `tmux` and `zsh` also redundantly `brew install` their own binary via `creates:` guard, so the role works standalone too).

Two config-deployment patterns are used depending on whether a tool has a native import mechanism:

- **Native import** (`iterm2`, `btt`): preferences are exported from the GUI app into `roles/<name>/files/*.plist` / `*.bttpreset`, then re-imported via `defaults import` or `osascript ... import_preset`. To update these, change the setting in the app, re-export, and overwrite the file — there's no task-level diffing of individual settings. BTT requires the app to already be running for the import to succeed (see comment in `roles/btt/tasks/main.yml`).
- **Template + LaunchAgent** (`keyboard`, `shares`): a `.j2` template or static plist is deployed, then loaded as a LaunchAgent so the effect survives reboot/logout. `hidutil` (keyboard) and `mount_smbfs` (shares) settings are otherwise session-only, which is why every such role pairs a "deploy the plist" task with a "load it now" task — both must run for the change to be both immediate and persistent.

### `shares` role specifics

- Personal-only — gated by `when: profile == 'personal'` in `mac.yml`, never runs on the work laptop.
- Mounts SMB shares from host `nas` via a generated shell script (`templates/mount-nas.sh.j2`, deployed 0700 because it embeds the plaintext password after vault decryption) plus a LaunchAgent (`com.theemm.nasmount`) that reconnects on login/interval (`remount_interval`, default 120s).
- The SMB password lives in `roles/shares/defaults/main.yml` as an inline `!vault` block, decrypted with `~/.vault_pass` (not in the repo). Any playbook run touching this role needs `--vault-password-file ~/.vault_pass` or an equivalent vault config — it isn't set in `ansible.cfg`, so pass it explicitly or configure `vault_password_file` locally.
- Share names (`smb_shares` in defaults) have flip-flopped across several commits (`share`/`edward-share` vs `Public`/`Edward`) — check actual Finder/`smbutil` share names before "fixing" these again rather than reverting blind.
- A one-time manual cleanup (removing old `/etc/auto_smb`/`auto_nfs` autofs entries) is documented as a comment at the top of `roles/shares/tasks/main.yml` — it's not automated because it needs `sudo`.

### `brew` role

`roles/brew/defaults/main.yml` is the single source of truth for taps/formulae/casks/VSCode extensions — it replaced an earlier `brew bundle`/Brewfile approach (see git history). Add packages there, not via ad hoc `brew install`.

### `keyboard` role

Caps Lock → Ctrl remap via `hidutil` (session-only) plus a LaunchAgent (`com.local.hidutil.keyboard.plist`) that reapplies it on login. The hex usage codes in `PLAN.md` (`0x700000039` / `0x7000000E0`) and the decimal ones actually used in `roles/keyboard/tasks/main.yml` (`30064771129` / `30064771296`) are the same values in different bases — don't "fix" one to match the other's format.
