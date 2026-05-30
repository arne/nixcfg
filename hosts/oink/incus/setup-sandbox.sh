#!/usr/bin/env bash
# Idempotent setup of the client-sandbox profile. Run once on oink (re-running
# is safe — the profile is declared via `incus profile edit`, which replaces
# the whole definition):
#   sudo sandbox-setup
#
# Egress hardening is NOT done here — it lives in host nftables (see
# hosts/oink/incus.nix), because per-NIC Incus network ACLs race the
# container's first-boot DHCP. The profile just gives each client an
# unprivileged, resource-capped box with a TUN device for Tailscale.

set -euo pipefail

echo "==> profile: client-sandbox"
incus profile create client-sandbox 2>/dev/null || true
incus profile edit client-sandbox <<'YAML'
description: Per-client Claude sandbox — unprivileged, resource-capped
config:
  limits.cpu: "2"
  limits.memory: 4GiB
devices:
  root:
    type: disk
    path: /
    pool: default
    size: 25GiB
  eth0:
    type: nic
    network: incusbr0
  tun:
    type: unix-char
    source: /dev/net/tun
    path: /dev/net/tun
YAML

echo "==> done. profile in place:"
incus profile show client-sandbox | sed 's/^/    /'
