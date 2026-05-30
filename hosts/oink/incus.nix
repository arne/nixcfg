{ pkgs, config, ... }:

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

  # Containers need the bridge's DHCP/DNS (dnsmasq on the host). We do NOT trust
  # the whole interface — the host opens :22 globally for WAN SSH, which would
  # otherwise be reachable from the bridge. Allowing only 53/67 here, plus the
  # sandbox-egress table below (which drops the rest of container→host TCP and
  # container→internal), keeps the host + LAN out of reach.
  networking.firewall.interfaces.incusbr0.allowedUDPPorts = [ 53 67 ];
  networking.firewall.interfaces.incusbr0.allowedTCPPorts = [ 53 ];

  # Egress hardening, host-side. Done in nftables (priority -10, ahead of both
  # the NixOS firewall and Incus's own tables, so a drop here is final) rather
  # than via Incus per-NIC network ACLs — those race the container's first-boot
  # DHCP and wedge it. Internet + intra-fleet (10.100.0.0/24) + tailnet-B
  # WireGuard all stay open; only host/LAN/metadata are cut off.
  networking.nftables.tables.sandbox-egress = {
    family = "inet";
    content = ''
      # container -> outside world: block the host's public /24 (host +
      # neighbouring customers), private LANs, and link-local/metadata.
      chain forward {
        type filter hook forward priority -10; policy accept;
        iifname "incusbr0" ip daddr { 169.254.0.0/16, 172.16.0.0/12, 185.181.63.0/24, 192.168.0.0/16 } drop
      }
      # container -> host: allow only DNS (UDP/TCP 53); drop the rest of TCP to
      # 10.100.0.1 (notably the globally-open :22). DHCP (UDP 67) is untouched.
      chain hostports {
        type filter hook input priority -10; policy accept;
        iifname "incusbr0" ip daddr 10.100.0.1 tcp dport != 53 drop
      }
    '';
  };

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

  ###########################################################################
  ## Admin + provisioning tooling.
  ##   sops / ssh-to-age — edit secrets/oink.yaml (the tailnet-B OAuth secret).
  ##   sandbox-setup      — create the egress ACL + client-sandbox profile (idempotent).
  ##   sandbox-new-client — mint a tailnet-B key + launch one client container.
  ## The two scripts live in ./incus/ and are packaged with pinned deps.
  ###########################################################################
  environment.systemPackages = [
    pkgs.sops
    pkgs.ssh-to-age
    (pkgs.writeShellApplication {
      name = "sandbox-setup";
      runtimeInputs = [ config.virtualisation.incus.clientPackage ];
      text = builtins.readFile ./incus/setup-sandbox.sh;
    })
    (pkgs.writeShellApplication {
      name = "sandbox-new-client";
      runtimeInputs = [ config.virtualisation.incus.clientPackage pkgs.jq pkgs.curl ];
      text = builtins.readFile ./incus/new-client.sh;
    })
  ];
}
