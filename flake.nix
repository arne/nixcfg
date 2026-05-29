{
  description = "Arne's NixOS configuration — multi-host flake (currently: fox)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

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
  };

  outputs = { self, nixpkgs, home-manager, niri, launcher, llm-agents, ... }:
    {
      nixosConfigurations.fox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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
    };
}
