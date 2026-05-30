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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, niri, launcher, llm-agents, disko, ... }:
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
            programs.niri.package = niri.packages.${pkgs.system}.niri-unstable;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.arne = import ./hosts/fox/home.nix;
            home-manager.extraSpecialArgs = { inherit launcher llm-agents; };
          }
        ];
      };

      # oink — headless server (gigahost.no, formerly srv2847). No desktop/niri
      # machinery. disko owns partitioning; ZFS root on sdb, data on sdc, Debian
      # on sdd left intact as a fallback during the remote cutover.
      nixosConfigurations.oink = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/oink/disko.nix
          ./hosts/oink/hardware-configuration.nix
          ./hosts/oink/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.arne = import ./hosts/oink/home.nix;
          }
        ];
      };
    };
}
