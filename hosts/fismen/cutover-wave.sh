#!/usr/bin/env bash
# Cut one wave of instances over to this host (run ON OINK for Phase 2;
# mirror the remote/profile args for Phase 5 move-back).
#
#   ./cutover-wave.sh tinyauth cal clips
#
# Per instance: stop on the source -> final incremental refresh -> re-assert
# the IP pin (refresh can resync config from the unpinned source) -> start
# here. DNS is NOT flipped here — run dns-flip.sh afterwards, then
# check-vhosts.sh. Source instances stay stopped-not-deleted (rollback path).
set -euo pipefail
REMOTE=${REMOTE:-fismen}
PROFILE=${PROFILE:-fismen}

# instance:last-octet pins (hosts/fismen/MIGRATION.md inventory)
declare -A PIN=( [a]=204 [abase]=104 [auth]=231 [b]=137 [bases-dev]=167
  [beszel]=118 [blog]=175 [bookmarks]=77 [burball]=59 [cal]=79
  [chat-posta]=208 [clips]=49 [coffee]=111 [comet]=218 [filebrowser]=67
  [gatus]=102 [glance]=196 [keys]=29 [marki]=122 [martin]=200 [msg-web]=173
  [orbit]=78 [outline]=254 [posta]=168 [posta-web]=240 [themes]=116
  [tinyauth]=250 [tjue]=2 [tjue-preview]=74 [tp]=103 [tv]=136
  [vaultwarden]=31 )

for n in "$@"; do
  ip="10.228.107.${PIN[$n]:?no IP pin known for $n}"
  echo "=== $n (pin $ip)"
  echo "--- stopping on $REMOTE"
  incus stop "$REMOTE:$n" || echo "    (already stopped?)"
  echo "--- final refresh"
  incus copy "$REMOTE:$n" "$n" --refresh -p "$PROFILE"
  echo "--- re-assert IP pin"
  incus config device override "$n" eth0 "ipv4.address=$ip" 2>/dev/null \
    || incus config device set "$n" eth0 "ipv4.address=$ip"
  echo "--- starting here"
  incus start "$n"
  incus list "$n" -c ns4 -f csv
done
echo "DONE. Now: dns-flip.sh for these vhosts, then check-vhosts.sh."
