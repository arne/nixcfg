{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
    ../../modules/ssh-keys.nix
  ];

  ###########################################################################
  ## Container foundation — LXC/Incus guest, DHCP on eth0, flakes enabled.
  ###########################################################################
  networking.hostName = "services";
  networking.useDHCP = false;
  networking.useHostResolvConf = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."50-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  ###########################################################################
  ## Nix — flakes, trusted users, numtide cache.
  ###########################################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "arne" ];
  nix.settings.extra-substituters = [ "https://cache.numtide.com" ];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  ###########################################################################
  ## SSH — root access required for nixos-rebuild --target-host, arne for
  ## interactive login.
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
    settings.PasswordAuthentication = false;
  };

  ###########################################################################
  ## Users
  ###########################################################################
  users.users.arne = {
    isNormalUser = true;
    uid = 1000;
    description = "Arne Skaar Fismen";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };
  # SSH keys come from the shared list in modules/ssh-keys.nix.
  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;

  ###########################################################################
  ## Packages
  ###########################################################################
  environment.systemPackages = with pkgs; [
    git
    htop
    curl
    jq
  ];

  ###########################################################################
  ## Pocket ID — passkey-based OIDC provider (verftet org).
  ###########################################################################
  services.pocket-id = {
    enable = true;
    settings = {
      APP_URL = "https://tilgang.verftet.info";
      TRUST_PROXY = true;
    };
  };

  ###########################################################################
  ## Pocket ID #2 — goltenstories org. One instance per org: passkeys are
  ## bound to the APP_URL domain and the user database must stay separate.
  ## The nixpkgs module is single-instance, so this is a hand-rolled unit on
  ## its own port + state dir (DB and uploads land in data/ relative to
  ## WorkingDirectory).
  ###########################################################################
  systemd.services.pocket-id-goltenstories = {
    description = "Pocket ID (goltenstories.no)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      APP_URL = "https://tilgang.goltenstories.no";
      TRUST_PROXY = "true";
      PORT = "1412";
    };
    serviceConfig = {
      ExecStart = lib.getExe pkgs.pocket-id;
      DynamicUser = true;
      StateDirectory = "pocket-id-goltenstories";
      WorkingDirectory = "/var/lib/pocket-id-goltenstories";
      Restart = "always";
      RestartSec = 1;
      # DynamicUser implies ProtectSystem=strict, PrivateTmp, NoNewPrivileges;
      # the rest mirrors the nixpkgs pocket-id module's hardening highlights.
      ProtectHome = true;
      PrivateDevices = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      UMask = "0077";
    };
  };

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
