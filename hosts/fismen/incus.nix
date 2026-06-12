{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Incus — general-purpose container/VM host for the fismen service fleet
  ## (~35 instances: vaultwarden, outline, posta, gatus, beszel, tinyauth, …).
  ##
  ## This is NOT the oink sandbox use-case — no per-tenant egress hardening. The
  ## goal is to reproduce the EXISTING bridge so imported instances keep working:
  ##   bridge incusbr0 = 10.228.107.1/24 (+ fd42:4920:83b2:cb09::1/64 ULA)
  ## Caddy targets (hosts/fismen/Caddyfile) are hardcoded 10.228.107.x addresses,
  ## so instances MUST keep their current IPs on import — pin each NIC's
  ## ipv4.address (or set dnsmasq reservations) rather than relying on DHCP.
  ##
  ## Storage is the rpool/incus dataset (disko); Incus makes its own children.
  ###########################################################################

  # nftables is REQUIRED by the NixOS Incus module (the iptables backend fails
  # eval). Incus manages its own tables for bridge NAT/DHCP.
  networking.nftables.enable = true;

  # Containers need the bridge's DHCP/DNS (dnsmasq on the host).
  networking.firewall.interfaces.incusbr0.allowedUDPPorts = [ 53 67 ];
  networking.firewall.interfaces.incusbr0.allowedTCPPorts = [ 53 ];

  virtualisation.incus = {
    enable = true;

    # Feature release (7.x) to match oink — the move-back copies instances
    # oink → fismen, and the migration target must be >= the source version.
    # (oink was bumped off incus-lts for the same reason; keep these in sync.)
    package = pkgs.incus;

    # Declarative first-init. Re-runs `incus admin init --preseed` on each
    # (re)start; it updates existing entities rather than recreating them.
    preseed = {
      storage_pools = [
        {
          name = "default";
          driver = "zfs";
          config.source = "rpool/incus"; # disko dataset
        }
      ];

      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.228.107.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "fd42:4920:83b2:cb09::1/64";
            "ipv6.nat" = "true";
          };
        }
      ];

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

  # incus CLI for the admin.
  environment.systemPackages = [ config.virtualisation.incus.clientPackage ];
}
