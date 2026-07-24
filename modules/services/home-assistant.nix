{ config, pkgs, lib, ... }:

{
  ###########################################################################
  ## Home Assistant + ESPHome — home automation on the LAN box.
  ##
  ## Native nixpkgs modules, not containers: state is small and lives on the
  ## NVMe (/var/lib/hass, /var/lib/esphome), so none of it belongs on the
  ## /mnt/form USB archive — that disk is `nofail` and can boot absent.
  ##
  ## Reachable from BOTH the LAN and the tailnet (openFirewall on each), so a
  ## wall tablet or a Chromecast can hit it directly while phones off-network
  ## come in over Tailscale. Nothing is exposed publicly — this host sits
  ## behind the home router's NAT and only :22 was open before this.
  ##
  ## DECLARATIVE CONFIG CAVEAT: setting `config` below makes
  ## configuration.yaml read-only and REWRITES IT ON EVERY START. That is the
  ## point (the file is owned by this repo), but it means anything you'd
  ## normally hand-edit in YAML has to land here instead. Integrations added
  ## through the web UI are unaffected — those live in .storage as config
  ## entries, which is where nearly everything goes these days.
  ##
  ## Adding an integration that needs a Python dep it doesn't already pull in
  ## means adding it to extraComponents and rebuilding; the UI cannot install
  ## it on its own the way HAOS/container installs can.
  ##
  ## BACKUPS: /var/lib/hass holds the entire automation state — .storage, the
  ## recorder database, and every credential HA has been handed. It is not
  ## backed up by anything in this repo yet.
  ###########################################################################

  ## The NUC has an on-board BT radio (hci0), but NixOS leaves BlueZ off by
  ## default — and default_config below enables HA's `bluetooth` integration,
  ## which discovers the adapter and then fails on every scan with
  ## "Failed to force stop scanner" because there's no bluetooth.service to
  ## talk to. Enabling BlueZ is the half that was missing, and it's what makes
  ## BLE sensors / presence detection usable at all.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.home-assistant = {
    enable = true;

    # default_config pulls the usual onboarding baseline (discovery, mobile
    # app, history, logbook, …). The rest are the ones worth having declared
    # rather than discovered: met is yr.no, which is the sensible weather
    # source given time.timeZone is Europe/Oslo.
    extraComponents = [
      "default_config"
      "esphome"
      "met"
      "radio_browser"
      "backup"
    ];

    config = {
      default_config = { };

      homeassistant = {
        name = "Home";
        unit_system = "metric";
        temperature_unit = "C";
        # Single source of truth — follows the host's own tz setting.
        time_zone = config.time.timeZone;
        country = "NO";
        currency = "NOK";
        # latitude/longitude are intentionally omitted: onboarding writes
        # them into .storage on first run, and duplicating them here would
        # just be a second place to keep them correct.
      };

      # Still listening on all interfaces: plain :8123 stays available on the
      # LAN for clients that can't do TLS (and as a way back in if caddy or
      # the cert breaks). https://ha.azf.no fronts it via caddy on the same
      # host — see hosts/meow/caddy.nix.
      #
      # trusted_proxies is REQUIRED once anything reverse-proxies HA: without
      # it every forwarded request is rejected, because HA would otherwise see
      # all traffic as originating from 127.0.0.1 and lose the real client IP
      # (which its rate-limiting and ban logic depend on). Only loopback is
      # trusted — caddy runs on this host.
      http = {
        server_host = [ "0.0.0.0" "::" ];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" "::1" ];
      };
    };

    openFirewall = true;
  };

  services.esphome = {
    enable = true;
    address = "0.0.0.0";
    openFirewall = true;

    # The ESP32 on this host enumerates as /dev/ttyACM0 (Espressif native USB
    # JTAG/serial). The module's default list is char-ttyS + char-ttyUSB
    # only, which does NOT match ttyACM — without char-ttyACM the dashboard
    # comes up fine but USB flashing fails to see the board. Device
    # CATEGORIES rather than /dev/serial/by-id paths, because an absolute
    # path only grants access to a device already plugged in when the unit
    # starts.
    allowedDevices = [ "char-ttyS" "char-ttyUSB" "char-ttyACM" ];
  };
}
