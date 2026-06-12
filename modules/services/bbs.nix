{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## bbs — SSH BBS on :2222.
  ##
  ## Runs the VENDOR BINARY at /opt/bbs/bbs (Go, dynamically linked against
  ## glibc only — verified with ldd on the live host), so on NixOS it is
  ## launched through the nix glibc loader. The source repo isn't published
  ## on the forge yet, so pkgs/bbs.nix stays a scaffold; switch ExecStart to
  ## the package once that lands.
  ##
  ## State: /var/lib/bbs (sqlite db + SSH host key). The host key MUST be
  ## migrated with the state dir or every user gets known_hosts warnings.
  ## Migration runbook: rsync /var/lib/bbs + the binary (live path was
  ## /usr/local/bin/bbs → /opt/bbs/bbs here), then chown -R bbs:bbs both.
  ## (On the live Debian host the state dir was root-owned, which crash-looped
  ## the service for months — ownership matters.)
  ###########################################################################

  users.users.bbs = {
    isSystemUser = true;
    group = "bbs";
  };
  users.groups.bbs = { };

  systemd.services.bbs = {
    description = "SSH BBS";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      BBS_ADDR = ":2222";
      BBS_DB = "/var/lib/bbs/bbs.db";
      BBS_HOST_KEY = "/var/lib/bbs/host_key";
      BBS_NAME = "THE BBS";
    };

    serviceConfig = {
      # Vendor binary needs the glibc dynamic loader (no FHS /lib64 on NixOS).
      ExecStart = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2 /opt/bbs/bbs";
      User = "bbs";
      Group = "bbs";
      StateDirectory = "bbs";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  networking.firewall.allowedTCPPorts = [ 2222 ];
}
