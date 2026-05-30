{ config, lib, pkgs, ... }:

{
  options.motd.animal = lib.mkOption {
    type = lib.types.str;
    default = "fox";
    description = "Mark animal shown on the left of the motd (a marks/animals name, e.g. \"fox\", \"piggy\").";
  };

  config.xdg.configFile."motd/config.yaml".source =
    pkgs.replaceVars ../files/motd/config.yaml { inherit (config.motd) animal; };
}
