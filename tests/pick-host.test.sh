#!/usr/bin/env bash
# Checks that scripts/pick-host.sh resolves Macs from hosts.nix alone and
# adds an unknown Mac with only its host name supplied.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PICK="$DIR/scripts/pick-host.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$DIR/hosts.nix" "$TMP/hosts.nix"
export PICK_HOST_FILE="$TMP/hosts.nix"
fail=0
check() {
  local want="$1" got; shift
  got="$(env "$@" "$PICK" </dev/null 2>/dev/null || true)"
  if [ "$got" = "$want" ]; then echo "ok - $want <= $*"; else echo "not ok - want '$want' got '$got' <= $*"; fail=1; fi
}
check rac PICK_HOST_USER=rac PICK_HOST_COMPUTER=Anything
check mehul-mac PICK_HOST_USER=mehul PICK_HOST_COMPUTER=Anything
check mehul-mac PICK_HOST_USER=someone PICK_HOST_COMPUTER=Mehul-Mac
if "$PICK" not-a-host </dev/null >/dev/null 2>&1; then echo "not ok - unknown explicit host accepted"; fail=1; else echo "ok - unknown explicit host refused"; fi

# Unknown Mac without a terminal: added under the suggested name.
check ppc-mini-tech PICK_HOST_USER=ops PICK_HOST_COMPUTER="PPC Mini Tech"
check ppc-mini-tech PICK_HOST_USER=ops PICK_HOST_COMPUTER="PPC Mini Tech"
# Unknown Mac with a chosen name.
check studio-2 PICK_HOST_USER=pp PICK_HOST_COMPUTER="Studio" PICK_HOST_NAME=studio-2
check "" PICK_HOST_USER=x PICK_HOST_COMPUTER=Other PICK_HOST_NAME="Bad Name"
check "" PICK_HOST_USER=y PICK_HOST_COMPUTER=Other2 PICK_HOST_NAME=rac

got="$(nix eval --impure --json --expr "builtins.mapAttrs (_: h: h.user) (import $TMP/hosts.nix)")"
if [ "$got" = '{"mehul-mac":"mehul","ppc-mini-tech":"ops","rac":"rac","studio-2":"pp"}' ]; then
  echo "ok - hosts.nix still evaluates with the added Macs"
else
  echo "not ok - hosts.nix after adds: $got"; fail=1
fi
exit "$fail"
