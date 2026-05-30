#!/usr/bin/env bash
# Provision one client sandbox.
#   sudo sandbox-new-client --cohort <client> --user <login>
#
# Example: sudo sandbox-new-client --cohort firsthouse --user alice
#
# Claims a free hostname from the fixed Studio-Ghibli pool below — no two live
# containers ever share one — then provisions a single-tenant box for one
# employee:
#   * mints a fresh, single-use auth key for the SEPARATE sandbox tailnet
#     (tailnet B) stamped with two tags: the cohort tag (tag:<cohort>, for the
#     shared :8080 service) and a per-box tag (tag:<cohort>-<login>, so the
#     tailnet-B ssh policy can scope login to ONLY this employee);
#   * launches the container, joins tailnet B, and creates the local Unix
#     account <login> (wheel + passwordless sudo) so they land as themselves
#     via Tailscale SSH (`ssh <login>@<hostname>`). No SSH keys involved —
#     authn/authz is the tailnet identity + the ssh ACL rule.
#
# Prereqs (all external, one-time per cohort — see hosts/oink/incus.nix header):
#   * `sandbox-setup` has run (profile exists); the `sandbox` image is imported;
#   * secrets/oink.yaml holds the tailnet-B OAuth client secret;
#   * the OAuth client OWNS tag:<cohort> and tag:<cohort>-<login> (admin console);
#   * tailnet B's policy defines tagOwners for those tags, plus the `ssh` rule
#     (employee -> their per-box tag, as user <login>) and the `acls` rule
#     (tag:<cohort> <-> tag:<cohort>:8080) for the shared service.

set -euo pipefail

usage() { echo "usage: sandbox-new-client --cohort <client> --user <login>" >&2; }

cohort=""
login=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cohort) cohort="${2:?--cohort needs a value}"; shift 2 ;;
    --user)   login="${2:?--user needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done
[ -n "$cohort" ] && [ -n "$login" ] || { echo "error: --cohort and --user are required" >&2; usage; exit 1; }

# Tag- and username-safe: lower-case, start with a letter, [a-z0-9-] thereafter.
safe='^[a-z][a-z0-9-]*$'
[[ "$cohort" =~ $safe ]] || { echo "error: --cohort must be lower-case [a-z0-9-], starting with a letter" >&2; exit 1; }
[[ "$login"  =~ $safe ]] || { echo "error: --user must be lower-case [a-z0-9-], starting with a letter" >&2; exit 1; }
cohort_tag="tag:${cohort}"
user_tag="tag:${cohort}-${login}"

# Hostname pool — Studio Ghibli characters, lower-case (DNS/Tailscale-safe).
# A name counts as taken if a live Incus instance OR a tailnet-B device already
# uses it, so a destroyed-but-lingering device is never silently re-handed-out
# and MagicDNS-suffixed. Grow capacity by adding names here.
pool=(
  totoro mei satsuki kanta kiki jiji osono tombo ursula okino
  chihiro sen haku yubaba zeniba kamaji lin boh howl markl
  heen suliman san eboshi jigo moro okkoto yakul toki pazu
  sheeta muska dola ponyo sosuke haru baron muta toto lune
  shizuku seiji sho pod marnie
)

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

# Names in use = live Incus instances ∪ every device in tailnet B. Both lookups
# must succeed (--fail + set -e); a silent failure here could double-assign.
echo "==> finding a free hostname"
ts_hostnames="$(
  curl -sS --fail \
    -H "Authorization: Bearer ${access_token}" \
    "https://api.tailscale.com/api/v2/tailnet/-/devices" | jq -r '.devices[].hostname'
)"
incus_names="$(incus list --format csv -c n)"
taken="$(printf '%s\n%s\n' "$ts_hostnames" "$incus_names")"

free=()
for n in "${pool[@]}"; do
  printf '%s\n' "$taken" | grep -qxF "$n" || free+=("$n")
done
if [ "${#free[@]}" -eq 0 ]; then
  echo "error: hostname pool exhausted — all ${#pool[@]} names are in use. Add more to the pool."
  exit 1
fi

# Random pick among the free names. $RANDOM is a bash builtin (no shuf/coreutils dep).
instance="${free[$((RANDOM % ${#free[@]}))]}"
echo "==> assigned hostname: ${instance} (${#free[@]}/${#pool[@]} free)"

echo "==> minting a single-use key for ${instance} (${cohort_tag}, ${user_tag})"
# NB: the Tailscale keys API rejects non-ASCII in `description` ("description
# had invalid characters"), so keep this plain ASCII — no em-dash.
key_body="$(jq -n \
  --arg desc "sandbox ${instance} (${cohort}/${login})" \
  --arg t1 "$cohort_tag" --arg t2 "$user_tag" \
  '{capabilities:{devices:{create:{reusable:false,ephemeral:false,preauthorized:true,tags:[$t1,$t2]}}},expirySeconds:600,description:$desc}')"
# No --fail here: we want the API's error body. curl/network failure still trips
# set -e via the empty-key check below.
mint_resp="$(
  curl -sS \
    "https://api.tailscale.com/api/v2/tailnet/-/keys" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    --data-binary "$key_body"
)"
authkey="$(printf '%s' "$mint_resp" | jq -r '.key // empty')"
if [ -z "$authkey" ]; then
  echo "error: failed to mint auth key. Tailscale said:" >&2
  printf '%s\n' "$mint_resp" | jq -r '.message // .' >&2
  echo "Check the OAuth client has auth_keys write and OWNS ${cohort_tag} + ${user_tag}" >&2
  echo "(tagOwners must let the client's tag own them — see cohorts.md)." >&2
  exit 1
fi

echo "==> launching ${instance} (sandbox image, client-sandbox profile)"
incus launch sandbox "$instance" --profile client-sandbox

# Wait for a DHCP lease. First boot can race networkd bring-up; the in-image
# sandbox-net-ensure service self-heals, but bounce networkd here too so
# provisioning is prompt rather than waiting on the in-image backoff.
wait_for_lease() {
  for _ in $(seq 1 "${1:-15}"); do
    if incus list "$instance" -c4 --format csv | grep -q '10\.100\.0\.'; then return 0; fi
    sleep 2
  done
  return 1
}
echo "==> waiting for DHCP lease"
if ! wait_for_lease 10; then
  echo "   no lease yet — forcing a clean DHCP cycle"
  incus exec "$instance" -- systemctl restart systemd-networkd
  wait_for_lease 15 || { echo "error: ${instance} never got a lease"; exit 1; }
fi

# Local account the employee lands as via Tailscale SSH. wheel -> passwordless
# sudo (the image sets security.sudo.wheelNeedsPassword = false). mutableUsers
# defaults true in the image, so this imperative add persists.
echo "==> creating local user '${login}'"
# shellcheck disable=SC2016  # $LOGIN is expanded by the container's bash (via --env), not here.
incus exec "$instance" --env LOGIN="$login" -- bash -c '
  set -eu
  if ! id "$LOGIN" >/dev/null 2>&1; then
    useradd -m -G wheel -s /run/current-system/sw/bin/bash "$LOGIN"
  fi
'

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
echo "Login:   ssh ${login}@${instance}    (over tailnet B, Tailscale SSH — no key needed)"
echo "Tags:    ${cohort_tag}, ${user_tag}"
echo "Policy:  tailnet B must grant ${login}'s identity SSH to ${user_tag} as user '${login}',"
echo "         and allow ${cohort_tag} <-> ${cohort_tag}:8080 for the shared service."
