#!/usr/bin/env bash
# Provision one client sandbox.
#   sudo sandbox-new-client <client-name>
#
# Mints a fresh, single-use, tag:client-sandbox auth key for the SEPARATE
# sandbox tailnet (tailnet B) from the OAuth client secret in sops, launches a
# container from the `sandbox` image with the client-sandbox profile, injects
# the key + hostname, and triggers the in-container first-boot join.
#
# Prereqs: `sandbox-setup` has been run (ACL + profile exist); the `sandbox`
# image is imported; secrets/oink.yaml holds the OAuth client secret; tailnet
# B's ACL policy defines tagOwners for tag:client-sandbox.

set -euo pipefail

name="${1:?usage: sandbox-new-client <client-name>}"
instance="client-${name}"
secret_file="/run/secrets/tailscale-sandbox/oauth-client-secret"

[ -r "$secret_file" ] || { echo "error: cannot read ${secret_file} (run with sudo)"; exit 1; }
oauth_secret="$(cat "$secret_file")"
# The client id is embedded in the secret (tskey-client-<id>-<rest>); the keys
# API needs an OAuth2 access token (the raw secret as a bearer is rejected 403).
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

echo "==> minting a single-use tag:client-sandbox key for ${instance}"
authkey="$(
  curl -sS --fail \
    "https://api.tailscale.com/api/v2/tailnet/-/keys" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    --data-binary '{
      "capabilities": {"devices": {"create": {
        "reusable": false,
        "ephemeral": false,
        "preauthorized": true,
        "tags": ["tag:client-sandbox"]
      }}},
      "expirySeconds": 600,
      "description": "sandbox '"${instance}"'"
    }' | jq -r '.key'
)"
if [ -z "$authkey" ] || [ "$authkey" = "null" ]; then
  echo "error: failed to mint auth key — check the OAuth client's scope (auth_keys write)"
  echo "       and that tag:client-sandbox has tagOwners in tailnet B's ACL policy."
  exit 1
fi

echo "==> launching ${instance} (sandbox image, client-sandbox profile)"
incus launch sandbox "$instance" --profile client-sandbox

# Wait for a DHCP lease. First boot can race the per-NIC ACL nftables setup; the
# in-image sandbox-net-ensure service self-heals, but bounce networkd here too
# so provisioning is prompt rather than waiting on the in-image backoff.
wait_for_lease() {
  for _ in $(seq 1 "${1:-15}"); do
    if incus list "$instance" -c4 --format csv | grep -q '10\.100\.0\.'; then return 0; fi
    sleep 2
  done
  return 1
}
echo "==> waiting for DHCP lease"
if ! wait_for_lease 10; then
  echo "   no lease yet — forcing a clean DHCP cycle (first-boot ACL race)"
  incus exec "$instance" -- systemctl restart systemd-networkd
  wait_for_lease 15 || { echo "error: ${instance} never got a lease"; exit 1; }
fi

echo "==> injecting tailnet auth + hostname"
incus exec "$instance" -- mkdir -p /etc/sandbox
printf 'TS_AUTHKEY=%s\nTS_HOSTNAME=%s\n' "$authkey" "$instance" \
  | incus exec "$instance" -- tee /etc/sandbox/tailscale.env >/dev/null
incus exec "$instance" -- chmod 600 /etc/sandbox/tailscale.env

echo "==> joining tailnet B"
incus exec "$instance" -- systemctl restart tailscale-sandbox-up.service

echo "==> ${instance} provisioned. Tailscale state:"
incus exec "$instance" -- tailscale status || true
echo
echo "Client access: they SSH over tailnet B to ${instance} as user 'client'"
echo "(Tailscale SSH). Ensure tailnet B's ACL has an ssh rule landing them as 'client'."
