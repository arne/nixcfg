{ ... }:

{
  ###########################################################################
  ## Incus — multi-tenant container host. Each client gets one unprivileged
  ## system container to run Claude Code (bypass-permissions) inside a
  ## blast-radius-limited sandbox. This file is the host foundation (Phase 1):
  ## the daemon, its ZFS storage on the dedicated 250 GB SSD, and the NAT
  ## bridge. The client image, per-client profile, egress ACLs and the
  ## separate sandbox tailnet are layered on in later phases.
  ##
  ## Storage lives on the `incus` zpool (disko: the 250 GB SSD), kept off the
  ## OS rpool so a runaway container can't starve root of space or I/O.
  ###########################################################################

  # nftables is REQUIRED by the NixOS Incus module — the iptables backend
  # fails eval. Incus manages its own nftables tables for bridge NAT/DHCP.
  networking.nftables.enable = true;

  # The Incus bridge runs its own DHCP/DNS (dnsmasq); the host firewall would
  # otherwise drop those requests. Trusting the bridge only affects host INPUT
  # — container egress is constrained separately by Incus network ACLs (Phase 4).
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  virtualisation.incus = {
    enable = true;

    # Declarative first-init. The preseed service re-runs `incus admin init
    # --preseed` whenever incus.service (re)starts; it updates existing
    # entities rather than recreating them. Keep this in sync with reality —
    # changing the pool source or bridge here after first init can drift.
    preseed = {
      # ZFS storage on the dedicated SSD pool (created by disko / the one-time
      # manual `zpool create incus …`). Incus makes its own child datasets.
      storage_pools = [
        {
          name = "default";
          driver = "zfs";
          config.source = "incus";
        }
      ];

      # Private NAT bridge. Instances get 10.100.0.0/24 + NAT out the host's
      # uplink for internet egress (Claude API, package fetches). IPv6 off —
      # we don't hand public v6 to sandboxes.
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.100.0.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
          };
        }
      ];

      # Baseline profile: root disk on the SSD pool + a NIC on the bridge. The
      # hardened per-client profile (limits, quota, /dev/net/tun) comes in Phase 4.
      profiles = [
        {
          name = "default";
          devices = {
            root = {
              type = "disk";
              path = "/";
              pool = "default";
            };
            eth0 = {
              type = "nic";
              name = "eth0";
              network = "incusbr0";
            };
          };
        }
      ];
    };
  };
}
