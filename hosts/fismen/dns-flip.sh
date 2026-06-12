#!/usr/bin/env bash
# Flip A records to a new origin IP via the Cloudflare API — the Phase 2/5
# cutover lever. Operates only on records that currently point at $FROM, so
# it's safe to re-run and can't touch unrelated records.
#
# Usage:
#   CLOUDFLARE_API_TOKEN=... ./dns-flip.sh <from-ip> <to-ip> <host> [host...]
#   CLOUDFLARE_API_TOKEN=... ./dns-flip.sh --all <from-ip> <to-ip>
#
# Examples (Phase 2, fismen -> oink):
#   ./dns-flip.sh 135.181.130.98 185.181.63.4 nytta.fismen.no       # canary
#   ./dns-flip.sh 100.86.115.86 100.78.72.66 vault.fismen.no        # tailnet vhost
#   ./dns-flip.sh --all 135.181.130.98 185.181.63.4                 # everything left
#
# Proxied (orange-cloud) records flip origin invisibly; grey-cloud ones
# propagate within TTL (300 s).
set -euo pipefail
: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN}"

api() { curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "$@"; }

if [ "$1" = "--all" ]; then
  from=$2; to=$3; hosts=""
else
  from=$1; to=$2; shift 2; hosts="$*"
fi

zones=$(api "https://api.cloudflare.com/client/v4/zones?per_page=50" \
        | jq -r '.result[] | "\(.id) \(.name)"')

while read -r zid zname; do
  api "https://api.cloudflare.com/client/v4/zones/$zid/dns_records?type=A&content=$from&per_page=100" \
  | jq -r '.result[] | "\(.id) \(.name) \(.proxied)"' \
  | while read -r rid rname proxied; do
      if [ -n "$hosts" ]; then
        case " $hosts " in *" $rname "*) ;; *) continue;; esac
      fi
      res=$(api -X PATCH "https://api.cloudflare.com/client/v4/zones/$zid/dns_records/$rid" \
            --data "{\"content\":\"$to\"}" | jq -r '.success')
      echo "$rname: $from -> $to (proxied=$proxied) success=$res"
    done
done <<< "$zones"
