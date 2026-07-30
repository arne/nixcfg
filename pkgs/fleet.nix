{ lib, writeShellApplication, gum, nix, openssh, coreutils }:

# fleet — a small TUI over the NixOS estate, themed to match `bases`
# (files/tmux/bases.conf: green #4a9f82, orange #e07800, red #d95050, on the
# #1a1815 surfaces with #3a3630 borders).
#
#   fleet                 status table of every host in the flake
#   fleet status [host…]  same, optionally filtered
#   fleet update          gum picker → deploy the chosen host(s)
#   fleet update fox      deploy fox directly
#   fleet update -y fox   …without the confirm prompt
#
# DRIFT is decided by comparing the flake revision each host was built from
# (its system.configurationRevision, stamped in modules/base.nix) against the
# revision of the checkout fleet is looking at — a couple of cheap string reads,
# NOT an evaluation of every host's system closure (that took ~70s/run and,
# with a dirty tree, could not be cached). A dirty checkout compares as
# "<rev>-dirty", so any uncommitted deploy from the same HEAD reads up-to-date;
# commit before trusting drift to the file level.
#
# Deploys go out from ONE checkout via nixos-rebuild's --target-host/--build-host,
# so this needs to find it: $FLEET_FLAKE, else ~/nixcfg, else /home/arne/nixcfg.
# Installed fleet-wide from modules/base.nix, but `update` only works where the
# checkout lives; `status` renders everywhere (drift shows as "reachable" for a
# host that predates the configurationRevision stamp).
#
# nixos-rebuild is intentionally NOT a runtime input: it must be the host's own.

writeShellApplication {
  name = "fleet";
  runtimeInputs = [ gum nix openssh coreutils ];
  # Interactive tool where ssh-to-a-downed-host and a cancelled picker are
  # normal control flow, so errexit would fight us; keep nounset + pipefail.
  bashOptions = [ "nounset" "pipefail" ];
  text = ''
    # ── bases theme ────────────────────────────────────────────────────────
    green="#4a9f82"; orange="#e07800"; red="#d95050"
    border="#3a3630"; muted="#857e75"; ink="#141210"
    a_green=$'\e[38;2;74;159;130m'
    a_orange=$'\e[38;2;224;120;0m'
    a_red=$'\e[38;2;217;80;80m'
    a_muted=$'\e[38;2;133;126;117m'
    a_off=$'\e[0m'

    export GUM_CHOOSE_HEADER_FOREGROUND="$muted"
    export GUM_CHOOSE_CURSOR_FOREGROUND="$orange"
    export GUM_CHOOSE_SELECTED_FOREGROUND="$green"
    export GUM_CONFIRM_PROMPT_FOREGROUND="$muted"
    export GUM_CONFIRM_SELECTED_BACKGROUND="$green"
    export GUM_CONFIRM_SELECTED_FOREGROUND="$ink"
    export GUM_SPIN_SPINNER_FOREGROUND="$green"

    self=$(uname -n)

    # ── locate the flake checkout ──────────────────────────────────────────
    flakedir="''${FLEET_FLAKE:-}"
    if [ -z "$flakedir" ]; then
      for d in "$HOME/nixcfg" /home/arne/nixcfg; do
        if [ -e "$d/flake.nix" ]; then flakedir="$d"; break; fi
      done
    fi

    flake_hosts() {
      [ -n "$flakedir" ] || return 1
      nix eval --raw "$flakedir#nixosConfigurations" --apply \
        'cfgs: builtins.concatStringsSep " " (builtins.attrNames cfgs)' 2>/dev/null
    }

    # Revision this checkout is at (git-aware, so it matches inputs.self.* at
    # build time). Cheap: flake metadata only, no system evaluation.
    want_rev() {
      [ -n "$flakedir" ] || return 0
      nix eval --raw --impure --expr \
        "let f = builtins.getFlake \"git+file://$flakedir\"; in f.rev or f.dirtyRev or \"\"" \
        2>/dev/null
    }

    # ── probe one host (bash over stdin: fish-proof) ────────────────────────
    # Emits: activated \t configRevision
    # shellcheck disable=SC2016  # intentional: this runs on the far side, not here
    probe='gen=$(readlink /nix/var/nix/profiles/system)
    d=$(stat -c %y "/nix/var/nix/profiles/$gen" 2>/dev/null | cut -d. -f1)
    rev=$(nixos-version --json 2>/dev/null | sed -n '"'"'s/.*"configurationRevision":"\([^"]*\)".*/\1/p'"'"')
    printf "%s\t%s\n" "$d" "$rev"'

    probe_host() {
      local h=$1
      if [ "$h" = "$self" ]; then
        bash -c "$probe" 2>/dev/null
      else
        ssh -o BatchMode=yes -o ConnectTimeout=6 "$h" bash 2>/dev/null <<<"$probe"
      fi
    }

    # short, human form of a configuration revision ("b48d2f4", "b48d2f4+")
    shortrev() {
      local r=$1 base
      if [ -z "$r" ]; then printf -- '-'; return; fi
      base=''${r%-dirty}
      if [ "$r" != "$base" ]; then printf '%s+' "''${base:0:7}"; else printf '%s' "''${base:0:7}"; fi
    }

    # ── status ─────────────────────────────────────────────────────────────
    cmd_status() {
      local hosts=()
      if [ "$#" -gt 0 ]; then
        hosts=("$@")
      else
        # shellcheck disable=SC2207
        hosts=($(flake_hosts)) || true
      fi
      if [ "''${#hosts[@]}" -eq 0 ]; then
        echo "fleet: no hosts (no checkout found; pass host names or set FLEET_FLAKE)" >&2
        return 1
      fi

      local want; want=$(want_rev)

      # Probe every host in parallel — the only slow part is the SSH timeout on
      # a downed host, so don't pay it serially.
      local tmp; tmp=$(mktemp -d)
      local h
      for h in "''${hosts[@]}"; do probe_host "$h" >"$tmp/$h" & done
      wait

      local header rows="" out d rev status
      header=$(printf '%s%-9s %-19s %-9s %s%s' \
        "$a_muted" HOST ACTIVATED REV STATUS "$a_off")
      for h in "''${hosts[@]}"; do
        out=$(cat "$tmp/$h" 2>/dev/null)
        if [ -z "$out" ]; then
          rows+=$(printf '%-9s %-19s %-9s %sunreachable%s' \
            "$h" "-" "-" "$a_red" "$a_off")$'\n'
          continue
        fi
        IFS=$'\t' read -r d rev <<<"$out"
        if [ -z "$rev" ]; then
          status="''${a_muted}reachable''${a_off}"
        elif [ -n "$want" ] && [ "$rev" = "$want" ]; then
          status="''${a_green}up-to-date''${a_off}"
        else
          status="''${a_orange}behind''${a_off}"
        fi
        rows+=$(printf '%-9s %-19s %-9s %b' \
          "$h" "$d" "$(shortrev "$rev")" "$status")$'\n'
      done
      rm -rf "$tmp"

      local title body
      title=$(gum style --bold --foreground "$ink" --background "$green" " fleet ")
      body="$title"$'\n\n'"$header"$'\n'"''${rows%$'\n'}"
      gum style --border rounded --border-foreground "$border" --padding "1 2" "$body"
    }

    # ── update ───────────────────────────────────────────────────────────────
    deploy_one() {
      local h=$1
      gum style --foreground "$green" --bold "▸ deploying $h"
      if [ "$h" = "$self" ]; then
        sudo nixos-rebuild switch --flake "$flakedir#$h"
      else
        nixos-rebuild switch --flake "$flakedir#$h" \
          --target-host "arne@$h" --build-host "arne@$h" --sudo
      fi
    }

    cmd_update() {
      local yes=0
      if [ "''${1:-}" = "-y" ] || [ "''${1:-}" = "--yes" ]; then yes=1; shift; fi

      if [ -z "$flakedir" ]; then
        echo "fleet update: no flake checkout found (set FLEET_FLAKE)" >&2
        return 1
      fi

      local targets=()
      if [ "$#" -gt 0 ]; then
        targets=("$@")
      else
        local all_line; all_line=$(flake_hosts) || true
        local all_arr; read -ra all_arr <<<"$all_line"
        # shellcheck disable=SC2207
        targets=($(printf '%s\n' "''${all_arr[@]}" | gum choose --no-limit \
          --header "Select host(s) to update")) || return 0
      fi
      if [ "''${#targets[@]}" -eq 0 ]; then
        echo "fleet: nothing selected" >&2
        return 0
      fi

      if [ "$yes" -eq 0 ]; then
        gum confirm "Deploy: ''${targets[*]}?" || return 0
      fi

      local h rc=0
      for h in "''${targets[@]}"; do
        if deploy_one "$h"; then
          gum style --foreground "$green" "✓ $h updated"
        else
          gum style --foreground "$red" "✗ $h failed"; rc=1
        fi
      done
      return "$rc"
    }

    # ── dispatch ─────────────────────────────────────────────────────────────
    case "''${1:-status}" in
      status) shift 2>/dev/null || true; cmd_status "$@";;
      update) shift; cmd_update "$@";;
      -h|--help|help)
        cat <<'USAGE'
    fleet                  status of every host in the flake
    fleet status [host…]   status, optionally filtered
    fleet update           pick host(s) to deploy
    fleet update [-y] HOST deploy HOST (-y skips the confirm)
    USAGE
        ;;
      *) echo "fleet: unknown command '$1' (try: fleet --help)" >&2; exit 1;;
    esac
  '';

  meta = {
    description = "Themed TUI to show and deploy the NixOS fleet";
    mainProgram = "fleet";
  };
}
