{ lib, config, ... }:

{
  ###########################################################################
  ## SSH public keys — the single source of truth for Arne's authorized keys,
  ## trusted on every host (imported via modules/base.nix). Add a key here once
  ## and it lands on all hosts instead of being copied per-host / per-account.
  ##
  ## This module wires the list into the `arne` login everywhere. Root is left
  ## to each host: fox sets PermitRootLogin = "no" (root SSH disabled, so no
  ## keys), while oink references `config.mine.sshKeys` for root during bring-up.
  ###########################################################################
  options.mine.sshKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Arne's trusted SSH public keys, shared across all hosts.";
    default = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8r647rf/5m/GEXN1kIccmJItzT1sdI0k4FGYSq5AKi arne@mac"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoX8GswCzYqOs94smClAJBxAO0ZX2U2WaKgriZO2Z7R servo"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHb1GcfjCCMlzVsZw5Zku7UvbF3QrFPbP+kxFDU4a+H/9p2HalYD43ZkaJQphQMYqC1MIQd4Cjmg1RTbUTneC+M= aPad"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkHOi39HCigHCOneTKIiY+C809n6d3sNHd3hoy2Uq21 aMini"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8iwTusmiXgGpx7VxMXJ/3U6LbTbkEPw+dv4538dThs orbit"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhF6a+vyLLQl74q6BHVbqeVxstHUMwVyDM4649b81Bg fismen"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkjfCCcwrYPMff8OA6l5cJKaWBQ2RkbjcamyLib9uRM rootShell"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBoj+n9iDeEVkDm9Yms0KNjqChlhGFrP6Aokh/DFByX air"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmGloBn0yDmkJtsNEPQWYJdYBP1G0NNXeOw30r5801u ram"
    ];
  };

  # Every host grants these keys to the `arne` login.
  config.users.users.arne.openssh.authorizedKeys.keys = config.mine.sshKeys;
}
