#!/usr/bin/env bash
# Prints the hosts.nix entry for the Mac this runs on.
# Usage: scripts/pick-host.sh [host]
# An explicit host must exist in hosts.nix. Otherwise the logged-in user is
# matched against each entry's `user`, then the Computer Name against each
# entry's `computerName`. A Mac that matches nothing is added to hosts.nix:
# in a terminal it asks only for the host name (Enter keeps the suggested
# one); the user and Computer Name are filled in automatically.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOSTS="${PICK_HOST_FILE:-$DIR/hosts.nix}"
NIX_BIN="${NIX_BIN:-$(command -v nix)}"

hosts_json() {
  "$NIX_BIN" eval --impure --json --expr "
    builtins.mapAttrs (_: h: { user = h.user; computerName = h.computerName or \"\"; })
      (import $HOSTS)"
}

json="$(hosts_json)"
names="$(printf '%s' "$json" | /usr/bin/python3 -c 'import json,sys; print(" ".join(sorted(json.load(sys.stdin))))')"

if [ -n "${1:-}" ]; then
  if printf '%s' "$json" | /usr/bin/python3 -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.load(sys.stdin) else 1)' "$1"; then
    printf '%s\n' "$1"
    exit 0
  fi
  echo "Unknown host '$1'. hosts.nix has: $names" >&2
  exit 1
fi

user="${PICK_HOST_USER:-$(whoami)}"
computer="${PICK_HOST_COMPUTER-$(scutil --get ComputerName 2>/dev/null || true)}"
host="$(printf '%s' "$json" | /usr/bin/python3 -c '
import json, sys
hosts = json.load(sys.stdin)
user, computer = sys.argv[1], sys.argv[2].lower()
by_user = [n for n, h in hosts.items() if h["user"] == user]
if len(by_user) == 1:
    print(by_user[0]); sys.exit(0)
by_name = [n for n, h in hosts.items() if h["computerName"] and computer.startswith(h["computerName"].lower())]
if len(by_name) == 1:
    print(by_name[0])
' "$user" "$computer")"

if [ -z "$host" ]; then
  # New Mac: suggest a host name from the Computer Name, else the user.
  suggested="$(printf '%s' "${computer:-$user}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  suggested="${suggested:-$user}"
  host="$suggested"
  if [ -z "${PICK_HOST_NAME+x}" ] && [ -r /dev/tty ] && [ -t 0 -o -t 2 ]; then
    printf 'New Mac (user=%s, computer=%s). Host name [%s]: ' "$user" "${computer:-unknown}" "$suggested" >/dev/tty
    IFS= read -r answer </dev/tty || answer=""
    [ -n "$answer" ] && host="$answer"
  elif [ -n "${PICK_HOST_NAME:-}" ]; then
    host="$PICK_HOST_NAME"
  fi
  if ! printf '%s' "$host" | grep -Eq '^[a-z][a-z0-9-]*$'; then
    echo "Host name '$host' must be lowercase letters, digits and hyphens." >&2
    exit 1
  fi
  if printf '%s' "$json" | /usr/bin/python3 -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.load(sys.stdin) else 1)' "$host"; then
    echo "Host '$host' already exists in hosts.nix for another Mac; pass a different name." >&2
    exit 1
  fi
  /usr/bin/python3 - "$HOSTS" "$host" "$user" "$computer" <<'PY'
import sys
path, host, user, computer = sys.argv[1:5]
text = open(path).read().rstrip()
assert text.endswith("}"), "hosts.nix must end with }"
entry = (
    f"  {host} = {{\n"
    f"    user = \"{user}\";\n"
    f"    computerName = \"{computer}\";\n"
    f"    description = \"Added by scripts/pick-host.sh\";\n"
    f"    extraCasks = [ ];\n"
    f"  }};\n"
)
open(path, "w").write(text[:-1].rstrip() + "\n" + entry + "}\n")
PY
  echo "Added '$host' to hosts.nix (user=$user, computer=${computer:-unknown}). Commit it so the next rebuild knows this Mac." >&2
fi
printf '%s\n' "$host"
