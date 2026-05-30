{ config, lib, pkgs, ... }:

let
  cfg = config.motd;
  motdPkg = pkgs.callPackage ../pkgs/motd.nix { };
  configFile = pkgs.replaceVars ../files/motd/config.yaml { inherit (cfg) animal; };
in
{
  options.motd.animal = lib.mkOption {
    type = lib.types.str;
    default = "fox";
    description = ''
      Mark animal shown on the left of the motd (a marks/animals name, e.g.
      "fox", "piggy"). Set per host.
    '';
  };

  config = {
    environment.systemPackages = [ motdPkg ];

    # Rendered config lives in /etc so every user (and root) reads the same one
    # — not tied to any home directory. (Distinct path from the classic
    # /etc/motd file pam_motd would print, which we don't use.)
    environment.etc."motd.yaml".source = configFile;

    # motd is dynamic (live host info, services, pending updates) and emits
    # colour, so we show it as an interactive-shell greeting rather than the
    # static pam_motd file. Cover both shells so it's global across all users:
    # fish via fish_greeting, bash via its interactive init.
    programs.fish.interactiveShellInit = ''
      function fish_greeting
          ${lib.getExe motdPkg} -config /etc/motd.yaml
      end
    '';

    programs.bash.interactiveShellInit = ''
      ${lib.getExe motdPkg} -config /etc/motd.yaml
    '';
  };
}
