{
  description = "arne's multi-host flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Unstable, used as an overlay for individual packages that 25.11's pin is
    # too old for (currently: llama-cpp — 25.11 has build 6981, which predates
    # Gemma 4; unstable is 9190+). Lock so it doesn't drift.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri compositor (sodiboo's flake — canonical niri module + session).
    # Don't `follows = nixpkgs`: the flake serves prebuilt outputs from
    # niri.cachix.org, and the check-phase EGL test aborts in the build
    # sandbox so compiling locally fails.
    niri.url = "github:sodiboo/niri-flake";

    # Apple Silicon support (Asahi kernel, Mesa, firmware, asahi-audio).
    # Canonical home moved from tpwrules to nix-community. Tracks `main` for
    # the freshest kernel/Mesa. The flake ships its own binary cache — don't
    # `follows = nixpkgs` or every cache hit dies and we recompile the Asahi
    # kernel locally. Substituter URL + key are in docs/binary-cache.md.
    apple-silicon.url = "github:nix-community/nixos-apple-silicon";

    launcher = {
      url = "git+https://code.bas.es/arne/launcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI coding agents (pi, claude-code, codex, …). Numtide rebuilds these
    # daily against their own pinned nixpkgs and serves prebuilt outputs from
    # cache.numtide.com — don't `follows = nixpkgs` or every cache hit dies.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Declarative disk partitioning for the oink server host.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management (sops + age). Used on oink to ship the sandbox
    # tailnet's auth material encrypted in-repo; decrypted at activation with
    # oink's SSH host key. See secrets/ and hosts/oink/secrets.nix.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt nix-index database (weekly) so `comma` (`, foo`) can resolve a
    # binary to its package without us building the index locally first.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The firsthouse sandbox-portal system (Phase 6) — the Go portal app, the
    # Incus/LXC sandbox guest image, and the NixOS service module all live in
    # its own repo now. Public repo on code.bas.es, fetched over plain HTTPS (no
    # credentials needed, like launcher). Its nixpkgs follows ours; its own
    # llm-agents + nixos-generators stay pinned upstream (cache hits / image builder).
    firsthouse = {
      url = "git+https://code.bas.es/arne/firsthouse";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, niri, apple-silicon, launcher, llm-agents, disko, sops-nix, nix-index-database, firsthouse, ... }:
    {
      nixosConfigurations.fox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/fox/hardware-configuration.nix
          ./hosts/fox/configuration.nix
          niri.nixosModules.niri
          # Backup config.kdl uses 2026-era features (background-effect,
          # maximize-window-to-edges) so pin niri to unstable, not 25.08-stable.
          ({ pkgs, ... }: {
            programs.niri.package = niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ];
            home-manager.users.arne = import ./hosts/fox/home.nix;
            home-manager.extraSpecialArgs = { inherit launcher llm-agents; };
          }
        ];
      };

      # air — MacBook Air, Apple Silicon (aarch64), Asahi kernel via the
      # nix-community/nixos-apple-silicon flake. Same niri/home-manager stack
      # as fox; per-host niri output config is files/niri/air.kdl.
      nixosConfigurations.air = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          apple-silicon.nixosModules.apple-silicon-support
          ./hosts/air/hardware-configuration.nix
          ./hosts/air/configuration.nix
          niri.nixosModules.niri
          ({ pkgs, ... }: {
            programs.niri.package = niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ];
            home-manager.users.arne = import ./hosts/air/home.nix;
            home-manager.extraSpecialArgs = { inherit launcher llm-agents; };
          }
        ];
      };

      # oink — headless server (gigahost.no). No desktop/niri machinery; disko
      # owns partitioning (ZFS rpool mirrored across two SSDs, tank data pool
      # on the 8 TB HDD).
      nixosConfigurations.oink = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          firsthouse.nixosModules.firsthouse
          ./hosts/oink/disko.nix
          ./hosts/oink/hardware-configuration.nix
          ./hosts/oink/configuration.nix
          ./hosts/oink/firsthouse.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ];
            home-manager.users.arne = import ./hosts/oink/home.nix;
          }
        ];
      };
    };
}
