#!/usr/bin/env bash
# Deprovision one sandbox.
#   sudo sandbox-remove-client <hostname> [-y]
#
# Deletes the Incus instance AND its tailnet-B device, which frees the hostname
# for reuse (sandbox-new-client treats a name as taken if a live instance OR a
# tailnet-B device uses it). Either may be absent — an orphaned device with no
# instance (or vice versa) is still cleaned up.
#
# Prereqs: secrets/oink.yaml holds the tailnet-B OAuth client secret, and that
# OAuth client has devices write scope (needed to delete the device).

set -euo pipefail

assume_yes=
host=""
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) assume_yes=1; shift ;;
    -h|--help) echo "usage: sandbox-remove-client <hostname> [-y]"; exit 0 ;;
    -*) echo "error: unknown option: $1" >&2; exit 1 ;;
    *) host="$1"; shift ;;
  esac
done
[ -n "$host" ] || { echo "usage: sandbox-remove-client <hostname> [-y]" >&2; exit 1; }

secret_file="/run/secrets/tailscale-sandbox/oauth-client-secret"
[ -r "$secret_file" ] || { echo "error: cannot read ${secret_file} (run with sudo)"; exit 1; }
oauth_secret="$(cat "$secret_file")"
client_id="$(printf '%s' "$oauth_secret" | sed -E 's/^tskey-client-([^-]+).*/\1/')"

echo "==> exchanging OAuth client for an access token"
access_token="$(
  curl -sS --fail \
    -d "client_id=${client_id}" \
    -d "client_secret=${oauth_secret}" \
    "https://api.tailscale.com/api/v2/oauth/token" | jq -r '.access_token'
)"
if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
  echo "error: OAuth token exchange failed — check the client secret in secrets/oink.yaml."
  exit 1
fi

# What exists under this name?
instance_exists=
incus info "$host" >/dev/null 2>&1 && instance_exists=1

devices_json="$(
  curl -sS --fail \
    -H "Authorization: Bearer ${access_token}" \
    "https://api.tailscale.com/api/v2/tailnet/-/devices"
)"
mapfile -t device_ids < <(printf '%s' "$devices_json" | jq -r --arg h "$host" '.devices[] | select(.hostname == $h) | .id')

if [ -z "$instance_exists" ] && [ "${#device_ids[@]}" -eq 0 ]; then
  echo "nothing to remove: no Incus instance and no tailnet-B device named '${host}'."
  exit 0
fi

echo "About to remove '${host}':"
[ -n "$instance_exists" ] && echo "  - Incus instance (force-deleted, including its disk)"
for id in "${device_ids[@]}"; do echo "  - tailnet-B device id ${id}"; done

if [ -z "$assume_yes" ]; then
  printf 'Proceed? [y/N] '
  read -r reply
  case "$reply" in
    y | Y | yes | YES) ;;
    *) echo "aborted."; exit 1 ;;
  esac
fi

if [ -n "$instance_exists" ]; then
  echo "==> deleting Incus instance ${host}"
  incus delete --force "$host"
fi

for id in "${device_ids[@]}"; do
  echo "==> deleting tailnet-B device ${id}"
  curl -sS --fail -o /dev/null -X DELETE \
    -H "Authorization: Bearer ${access_token}" \
    "https://api.tailscale.com/api/v2/device/${id}" \
    || { echo "error: device ${id} delete failed — the OAuth client likely lacks devices write scope."; exit 1; }
done

echo "==> '${host}' removed. The hostname is free for reuse."
