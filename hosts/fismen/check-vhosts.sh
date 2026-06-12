#!/usr/bin/env bash
# Verify every vhost in the Caddyfile: where DNS points, whether HTTPS
# answers, and the cert's expiry. The Caddyfile IS the migration checklist —
# run after each cutover wave (Phase 2) and after the move-back (Phase 5).
#
# Usage:
#   ./check-vhosts.sh                  # check against live DNS
#   ./check-vhosts.sh 185.181.63.4     # force-resolve every host to this IP
#                                      # (pre-flip smoke test of the new box)
#
# Tailnet-only vhosts (vault.fismen.no, ai.azf.no) only answer from inside
# the tailnet; run from a tailnet machine or expect them to fail elsewhere.
set -u
caddyfile="$(dirname "$0")/Caddyfile"
force_ip="${1:-}"

hosts=$(grep -oE '^[a-z0-9*.-]+\.[a-z]{2,}' "$caddyfile" | sed 's/^\*\.//' | sort -u)

printf "%-28s %-18s %5s  %-10s %s\n" HOST DNS HTTP CERT-DAYS NOTE
fail=0
for h in $hosts; do
  ip=$(dig +short A "$h" @1.1.1.1 | head -1)
  target="${force_ip:-$ip}"
  resolve=()
  [ -n "$force_ip" ] && resolve=(--resolve "$h:443:$force_ip")

  code=$(curl -so /dev/null -w '%{http_code}' --max-time 10 "${resolve[@]}" "https://$h/" 2>/dev/null)

  end=$(echo | openssl s_client -servername "$h" -connect "$target:443" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  days=""
  if [ -n "$end" ]; then
    days=$(( ($(date -d "$end" +%s) - $(date +%s)) / 86400 ))
  fi

  note=""
  case "$code" in
    2*|3*|401) ;;                      # 401 = tinyauth-fronted, that's fine
    *) note="CHECK"; fail=1 ;;
  esac
  [ -z "$days" ] && { note="$note NO-CERT"; fail=1; }
  [ -n "$days" ] && [ "$days" -lt 14 ] && { note="$note EXPIRING"; fail=1; }

  printf "%-28s %-18s %5s  %-10s %s\n" "$h" "${ip:-none}" "${code:-ERR}" "${days:-—}" "$note"
done
exit $fail
