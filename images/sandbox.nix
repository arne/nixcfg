{ config, pkgs, lib, inputs, ... }:

{
  ###########################################################################
  ## Client sandbox guest (Incus/LXC image).
  ##
  ## One of these runs per client. The client SSHes in over the SEPARATE
  ## sandbox tailnet (tailnet B) and runs Claude Code with bypass permissions;
  ## the unprivileged container is the blast-radius boundary. This file is the
  ## generic image — per-instance bits (the tailnet-B auth key + hostname,
  ## resource limits, /dev/net/tun, egress ACL) are layered on at provisioning
  ## time (Phase 4). Built via packages.<system>.sandbox-{rootfs,metadata}.
  ###########################################################################

  # claude-code comes from the same numtide source the hosts use; pull in the
  # cache so the image build (and in-container `nix` use) gets prebuilt hits.
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.extra-substituters = [ "https://cache.numtide.com" ];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  environment.systemPackages = with pkgs; [
    inputs.llm-agents.packages.${pkgs.system}.claude-code
    git
    curl
    wget
    jq
    ripgrep
    fd
    gnumake
    # nix-ld-style vendor-binary support could be added later if clients need it.
  ];

  ###########################################################################
  ## The client identity. Inside an unprivileged container, root is already
  ## mapped to a non-root host uid, so passwordless sudo here stays contained;
  ## it just lets the client install tooling in their own box.
  ###########################################################################
  users.users.client = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };
  security.sudo.wheelNeedsPassword = false;

  ###########################################################################
  ## Tailscale — joins tailnet B (the sandbox tailnet), NOT the host's
  ## personal tailnet. The TUN device is provided by the Incus profile
  ## (/dev/net/tun, Phase 4). Access is via Tailscale SSH only — no openssh
  ## service is enabled, so the tailnet is the sole way in.
  ###########################################################################

  # Networking: DHCP on eth0 from Incus's bridge (the lxc image profile leaves
  # the guest with no network config, so set it explicitly). systemd-networkd
  # + resolved manage the lease and DNS; the lxc base sets useHostResolvConf,
  # which must be off or it conflicts with resolved.
  systemd.network.enable = true;
  services.resolved.enable = true;
  networking.useHostResolvConf = lib.mkForce false;
  networking.useDHCP = false;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
    linkConfig.RequiredForOnline = "routable";
  };

  # Defensive DHCP safety-net: if eth0 has no lease shortly after boot (a
  # transient DHCP failure / lost race with host-side setup), bounce networkd
  # to force a clean cycle, so the container always comes up with networking.
  systemd.services.sandbox-net-ensure = {
    description = "Ensure eth0 obtains a DHCP lease (first-boot ACL race)";
    after = [ "systemd-networkd.service" ];
    wants = [ "systemd-networkd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for _ in $(seq 1 10); do
        if ${pkgs.iproute2}/bin/ip -4 addr show eth0 | grep -q 'inet 10\.'; then exit 0; fi
        sleep 2
      done
      echo "eth0 still has no lease after 20s — bouncing networkd" >&2
      systemctl restart systemd-networkd
    '';
  };

  services.tailscale.enable = true;

  # First-boot join. The provisioner drops the per-instance auth material at
  # /etc/sandbox/tailscale.env (TS_AUTHKEY=…, TS_HOSTNAME=…); this oneshot
  # consumes it and brings Tailscale up with SSH. Idempotent: it no-ops once
  # the backend is already Running.
  systemd.services.tailscale-sandbox-up = {
    description = "Join the sandbox tailnet (tailnet B) on first boot";
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "tailscaled.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      ts=${lib.getExe config.services.tailscale.package}
      state=$("$ts" status --json 2>/dev/null | ${lib.getExe pkgs.jq} -r '.BackendState // "NoState"')
      if [ "$state" = "Running" ]; then
        echo "tailscale already up; nothing to do"
        exit 0
      fi
      if [ ! -f /etc/sandbox/tailscale.env ]; then
        echo "no /etc/sandbox/tailscale.env yet — provisioner hasn't injected auth; skipping" >&2
        exit 0
      fi
      . /etc/sandbox/tailscale.env
      exec "$ts" up --ssh --accept-routes=false \
        --authkey "$TS_AUTHKEY" \
        --hostname "$TS_HOSTNAME"
    '';
  };

  ###########################################################################
  ## Trim + pin. Keep the guest minimal; documentation/man-pages off to slim
  ## the image. Do NOT bump stateVersion casually.
  ###########################################################################
  documentation.enable = false;
  documentation.man.enable = false;

  system.stateVersion = "25.11";
}
