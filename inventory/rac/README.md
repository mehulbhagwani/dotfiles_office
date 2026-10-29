# Office laptop inventory (host `rac`, 29 Oct 2026)

A snapshot of what was installed and configured on the office MacBook Pro before it was formatted.
It records the machine as it was; `configuration.nix`, `home.nix` and `scripts/` are what actually install a new Mac.

| File | What it records |
|---|---|
| `Brewfile` | `brew bundle dump` of every tap, formula and cask |
| `brew-formulae.txt`, `brew-casks.txt` | Top-level Homebrew installs |
| `applications.txt` | `/Applications`, `~/Applications` and Home Manager apps |
| `npm-global.txt` | Global npm packages |
| `uv-tools.txt` | `uv tool` installs |
| `local-bin.txt` | `~/.local/bin` entries and their link targets |
| `home-manager-links.txt` | Files Home Manager links into `$HOME` from the Nix store |
| `other-symlinks.txt` | Remaining home symlinks (dotfiles, Nix profile, Synology Drive) |
| `config-dirs.txt` | `~/.config` entries, managed or not |
| `launch-agents.txt` | `~/Library/LaunchAgents` |
| `macos-defaults/` | `defaults read` of Dock, Finder, global, trackpad, screenshot, Stage Manager and clock settings |

## Declared from this snapshot

- Office-only casks added to `configuration.nix` for host `rac`: adobe-creative-cloud, blip, chatgpt, logi-options+, spotify, synology-drive, tailscale-app, vorssaint.
- npm CLIs added to `scripts/npm-globals.sh`: obsidian-axi, acpx, justroll, pi-acp, playwright, pnpm, screencast-axi, tsx.

## Not declarable, install by hand

- MiniMax Design, Keynote Creator Studio: no Homebrew cask.
- PPC-NAS, PPCSpeakerControl: in-house apps.
- figma-axi, rough-cut-axi: npm links to local clones under `~/.local/share`.
- Adobe apps: sign in to Creative Cloud, then install After Effects, Photoshop, Premiere Pro and Media Encoder.
- LaunchAgents for Synology Drive, no-mistakes, m87 and the Pitch Perfekt sound trigger are created by their apps.

## Not in this repo

Credentials stay out of git: SSH keys, `~/.config/gh/hosts.yml`, Codex and Pi `auth.json`, the Claude login and Tailscale state.
