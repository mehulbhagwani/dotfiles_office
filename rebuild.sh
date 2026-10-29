#!/usr/bin/env bash
# Apply this repo to the Mac you are on.
# Usage: ./rebuild.sh [host]   (hosts are listed in hosts.nix)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

HOST="$("$DIR/scripts/pick-host.sh" "${1:-}")"

echo "==> applying darwinConfigurations.$HOST"
# brew 7 will not load casks from an untrusted tap. Trust before the switch
# so pi-launcher is not skipped or pruned.
if command -v brew >/dev/null 2>&1 && brew tap | grep -qx 'kunchenguid/tap'; then
  brew trust kunchenguid/tap || true
fi
# Absolute path: sudo's PATH excludes /run/current-system/sw/bin, so a bare
# darwin-rebuild isn't found under sudo.
exec sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$DIR#$HOST"
