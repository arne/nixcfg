{ lib, config, ... }:

{
  ###########################################################################
  ## SSH public keys — the single source of truth for Arne's authorized keys,
  ## trusted on every host (imported via modules/base.nix). Add a key here once
  ## and it lands on all hosts instead of being copied per-host / per-account.
  ##
  ## This module wires the list into the `arne` login everywhere. Root SSH is
  ## disabled on every host (PermitRootLogin = "no"), so these keys are never
  ## granted to root — access is via the `arne` account only.
  ###########################################################################
  options.mine.sshKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Arne's trusted SSH public keys, shared across all hosts.";
    default = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8r647rf/5m/GEXN1kIccmJItzT1sdI0k4FGYSq5AKi arne@mac"
      # Regenerated 2026-07-24, when the box was reinstalled and renamed
      # servo -> meow. The previous entry here (…IEoX8GswCzYqOs94smClAJBx…)
      # is NOT this machine's key — no matching private key exists anywhere
      # under /home/arne on meow, whose keypair was created fresh after the
      # reinstall. It is still registered on the GitHub account, so if its
      # private half turns out to live on some other machine, re-add it under
      # that machine's own label rather than restoring it here.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICvd5YpeUcMgEOR/p/cwnu+toJyb/VjNcoUDSGIKd4ts meow"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHb1GcfjCCMlzVsZw5Zku7UvbF3QrFPbP+kxFDU4a+H/9p2HalYD43ZkaJQphQMYqC1MIQd4Cjmg1RTbUTneC+M= aPad"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkHOi39HCigHCOneTKIiY+C809n6d3sNHd3hoy2Uq21 aMini"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8iwTusmiXgGpx7VxMXJ/3U6LbTbkEPw+dv4538dThs orbit"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFarbcucH4DqIkXSnIok8VxIJLiryiAu9Eud/GzNMLsJ oink"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhF6a+vyLLQl74q6BHVbqeVxstHUMwVyDM4649b81Bg fismen"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkjfCCcwrYPMff8OA6l5cJKaWBQ2RkbjcamyLib9uRM rootShell"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBPR+ja1Ki3aj1/In+i5mytGsgW38hGqKBHuaG78qJk air"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmGloBn0yDmkJtsNEPQWYJdYBP1G0NNXeOw30r5801u fox"
    ];
  };

  # Every host grants these keys to the `arne` login.
  config.users.users.arne.openssh.authorizedKeys.keys = config.mine.sshKeys;
}
