#!/usr/bin/env bash
# Install the global npm CLIs this machine's workflow depends on.
#
# These are the -axi agent tools. They are neither Nix packages nor Homebrew
# formulae, so without this a rebuild on a fresh Mac produces a machine with
# none of them. Homebrew's `node` (declared in configuration.nix) is what they
# stand on; that dependency used to be transitive through pi-coding-agent.
#
# Deliberately unpinned: these ship often and are meant to track latest.
# A rebuild installs anything missing and updates the declared set.
set -euo pipefail

# Activation runs with a minimal PATH; npm lives in the Homebrew prefix.
export PATH="/opt/homebrew/bin:$PATH"

PACKAGES=(
  "@kunchenguid/m87"
  "@nikolauska/sentry-axi"
  az-axi
  backpass
  chrome-devtools-axi
  comfy-cloud-axi
  council-axi
  doctl-axi
  gh-axi
  gnhf
  gws-axi
  lavish-axi
  linear-sdk-axi
  mobbin-axi
  openpanel-axi
  quota-axi
  tasks-axi
  "@andershoffmann/obsidian-axi"
  acpx
  justroll
  pi-acp
  playwright
  pnpm
  screencast-axi
  tsx
)

command -v npm >/dev/null 2>&1 || { echo "npm-globals: npm not found, skipping"; exit 0; }

# A root-owned npm cache from an older sudo install must not block updates.
export npm_config_cache="${npm_config_cache:-$HOME/.cache/npm}"
mkdir -p "$npm_config_cache"

echo "npm-globals: installing or updating ${#PACKAGES[@]} packages"
npm install -g "${PACKAGES[@]}"
