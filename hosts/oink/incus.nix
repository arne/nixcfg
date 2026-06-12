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
      # container -> outside world: block all RFC1918 EXCEPT the sandbox bridge
      # (10.100.0.0/24 — sandboxes reaching each other over the tailnet is a
      # feature), the host's public /24 (host + neighbouring customers),
      # link-local/metadata, and the 100.64.0.0/10 tailnet overlay (so a
      # container can't route into oink's personal tailnet A). Tailnet-B traffic
      # is WireGuard-encapsulated to public endpoints, so it is unaffected.
      chain forward {
        type filter hook forward priority -10; policy accept;
        iifname "incusbr0" ip daddr 10.100.0.0/24 accept
        iifname "incusbr0" ip daddr { 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 185.181.63.0/24, 192.168.0.0/16 } drop
      }
      # container -> host: the host's services (notably the globally-open :22,
      # reachable on its public AND tailnet IPs) must stay out of reach. Packets
      # addressed to any of the host's own IPs land on INPUT, not forward, so we
      # key the drop on the ingress interface rather than the dest IP — keying on
      # daddr 10.100.0.1 alone left :22 open via 185.181.63.4 / the 100.x IP.
      # Allow only DNS + DHCP to the host; drop everything else from the bridge.
      chain hostports {
        type filter hook input priority -10; policy accept;
        iifname "incusbr0" udp dport { 53, 67 } accept
        iifname "incusbr0" tcp dport 53 accept
        iifname "incusbr0" drop
      }
    '';
  };

  virtualisation.incus = {
    enable = true;

    # Feature release (7.x), NOT the default incus-lts (6.0.x). Required to
    # RECEIVE migration copies from live fismen (zabbly incus 6.23): the
    # migration target must be >= the source version. NOTE: switching from
    # lts upgraded the daemon DB one-way — do not revert to incus-lts after
    # the fismen interim, this stays. The future fismen NixOS host runs the
    # same pkgs.incus so the move-back (7.x -> 7.x) is fine.
    package = pkgs.incus;

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
        ## FISMEN-INTERIM — second bridge reproducing live fismen's incusbr0
        ## exactly (same subnet + ULA) so the ~32 migrated instances keep
        ## their 10.228.107.x addresses and the Caddyfile targets stay valid.
        ## The sandbox-egress chains above match only `iifname "incusbr0"`,
        ## so this bridge is NOT hardened — and sandboxes can't reach it
        ## (10.228.107.0/24 falls inside their 10.0.0.0/8 drop). Remove this
        ## block (and the fismen profile below) after the move-back.
        {
          name = "incusbr1";
          type = "bridge";
          config = {
            "ipv4.address" = "10.228.107.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "fd42:4920:83b2:cb09::1/64";
            "ipv6.nat" = "true";
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
        ## FISMEN-INTERIM — profile for the migrated fismen instances:
        ## same SSD pool, but NIC on incusbr1 (10.228.107.0/24). Every
        ## `incus copy fismen:<x>` MUST use `-p fismen` (plus a per-instance
        ## pinned eth0 ipv4.address — see hosts/fismen/MIGRATION.md table).
        ## Remove after the move-back.
        {
          name = "fismen";
          devices = {
            root = {
              type = "disk";
              path = "/";
              pool = "default";
            };
            eth0 = {
              type = "nic";
              name = "eth0";
              network = "incusbr1";
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
  ##   sandbox-new-client — provision one employee box: `--cohort <client>
  ##                        --user <login>` (random Ghibli hostname, tags,
  ##                        Tailscale-SSH login). See ./incus/cohorts.md.
  ##   sandbox-remove-client — deprovision a box: delete the instance + its
  ##                        tailnet-B device, freeing the hostname.
  ## The scripts live in ./incus/ and are packaged with pinned deps.
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
    (pkgs.writeShellApplication {
      name = "sandbox-remove-client";
      runtimeInputs = [ config.virtualisation.incus.clientPackage pkgs.jq pkgs.curl ];
      text = builtins.readFile ./incus/remove-client.sh;
    })
  ];
}
