{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Nyheter — Norwegian news syndication server. Caddy proxies
  ## nyheter.fismen.no → 127.0.0.1:8083.
  ##
  ## Runs the VENDOR BINARY at /opt/nyheter/nyheter-server (statically linked
  ## Go — verified on the live host, runs fine on NixOS). The source repo
  ## isn't published on the forge yet, so pkgs/nyheter.nix stays a scaffold;
  ## switch ExecStart to the package once that lands.
  ##
  ## State: the sqlite db (~1 GB) lives next to the binary in /opt/nyheter.
  ## Migration runbook: rsync /opt/nyheter wholesale, then
  ##   chown -R nyheter:nyheter /opt/nyheter
  ##
  ## OIDC_CLIENT_ID / OIDC_CLIENT_SECRET come via EnvironmentFile — wire it on
  ## the host: systemd.services.nyheter.serviceConfig.EnvironmentFile =
  ##   config.sops.secrets."nyheter/oidc-env".path;
  ###########################################################################

  users.users.nyheter = {
    isSystemUser = true;
    group = "nyheter";
  };
  users.groups.nyheter = { };

  systemd.services.nyheter = {
    description = "Nyheter — Norwegian News Syndication";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    environment = {
      DATABASE_PATH = "/opt/nyheter/nyheter.db";
      LISTEN_ADDR = "127.0.0.1:8083";
      # llama host on the tailnet (cube).
      OLLAMA_URL = "http://100.121.19.125:11434";
    };

    serviceConfig = {
      ExecStart = "/opt/nyheter/nyheter-server";
      WorkingDirectory = "/opt/nyheter";
      User = "nyheter";
      Group = "nyheter";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
