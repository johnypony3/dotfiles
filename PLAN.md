# dotfiles — Mac Laptop Ansible Config

## Context

This is a new standalone Ansible repo for configuring Edward's Mac laptop.
Edward also has a `../skynet` repo — an Ansible + Kubernetes homelab for a
Linux NUC. The pattern in skynet is the reference: playbooks targeting
`localhost` with `connection: local`, vault-encrypted secrets, and LaunchAgents
for persistent config (see `../skynet/ansible/playbooks/mount-nas-mac.yml` for
a full working example of this pattern on macOS).

## What to build

### 1. Caps Lock → Ctrl remap (macOS, persistent)

Edward already did this manually via System Settings → Keyboard → Modifier Keys.
It needs to be codified in Ansible so it survives a fresh machine setup.

On macOS, modifier key remapping is stored in:
`~/Library/Preferences/com.apple.keyboard.modifiermapping`

The programmatic way is `hidutil`:
```bash
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}
]}'
```
- `0x700000039` = Caps Lock
- `0x7000000E0` = Left Control

`hidutil` changes are lost on reboot. Make them persistent via a LaunchAgent
(same pattern as `../skynet/ansible/playbooks/mount-nas-mac.yml`).

### 2. General laptop configuration

Configure this Mac via Ansible `osx_defaults` tasks and brew. Start by asking
Edward what he wants — common categories:

- **Homebrew packages**: what CLI tools and casks to install
- **macOS system defaults**: Dock, Finder, trackpad, keyboard repeat rate, etc.
- **Shell / dotfiles**: zsh config, aliases, `.gitconfig`
- **App configs**: anything else to deploy

## Repo structure to create

```
dotfiles/
├── inventory/
│   └── hosts.yml          # localhost only
├── playbooks/
│   └── mac.yml            # main mac playbook
├── roles/
│   └── keyboard/          # Caps Lock remap role
│       ├── tasks/main.yml
│       └── files/         # LaunchAgent plist template
├── group_vars/
│   └── all.yml
└── PLAN.md                # this file
```

### 3. Homebrew packages

Codify all currently installed brew formulae and casks into a `brew` role.
Run `brew bundle dump` to snapshot current state, then manage via Brewfile
or an explicit package list in the role.

### 4. iTerm2 configuration

Codify iTerm2 preferences. iTerm2 can export/import a `.itermocil` or
preferences plist. Use `com.googlecode.iterm2` defaults or deploy the
plist via Ansible.

### 5. BetterTouchTool configuration

Codify BTT configuration. BTT exports a `.bttpreset` file.
Deploy via Ansible and trigger an import on first run.

### 6. NAS share mount (import from skynet)

There is uncommitted work in `../skynet` (the `mount-nas-mac.yml` playbook and
related files) that configures the Mac NAS mount via LaunchAgent. That work
belongs here, not in skynet.

Steps:
1. Copy the uncommitted NAS mount files from `../skynet` into a `roles/nas/` role here
2. Remove those files from the skynet repo (leaving no trace)
3. Wire the `nas` role into `mac.yml`

## First steps

1. Ask Edward what general laptop config he wants (brew packages, defaults, etc.)
2. Build the `keyboard` role with the Caps Lock → Ctrl LaunchAgent
3. Wire up the main `mac.yml` playbook
4. Import NAS mount work from skynet into a `roles/nas/` role, remove from skynet
5. Commit and document how to run it (`ansible-playbook playbooks/mac.yml`)
