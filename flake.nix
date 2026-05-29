{
  description = "Arne's NixOS configuration — multi-host flake (currently: fox)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri compositor (sodiboo's flake — canonical niri module + session)
    niri.url = "github:sodiboo/niri-flake";

    launcher = {
      url = "git+https://code.bas.es/arne/launcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, niri, launcher, ... }:
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
            home-manager.extraSpecialArgs = { inherit launcher; };
          }
        ];
      };
    };
}
