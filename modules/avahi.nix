{ ... }:

{
  ###########################################################################
  ## Avahi — mDNS/DNS-SD daemon, always on. Shared across every host (imported
  ## via modules/base.nix). Makes `.local` hostnames resolve (and advertises
  ## this host's own `<hostname>.local`).
  ##
  ##   - nssmdns4 wires avahi into the glibc name-service switch, so *any*
  ##     resolver call (ping, curl, ssh, browsers) resolves `*.local`, not just
  ##     avahi-aware tools.
  ##   - publish.* advertises this host over mDNS so peers can find it by name.
  ##   - openFirewall opens UDP 5353 for mDNS.
  ###########################################################################
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}
