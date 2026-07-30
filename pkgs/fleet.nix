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
        ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new \
          "$h" bash 2>/dev/null <<<"$probe"
      fi
    }

    # short, human form of a configuration revision ("b48d2f4", "b48d2f4+")
    shortrev() {
      local r=$1 base
      if [ -z "$r" ]; then printf -- '-'; return; fi
      base=''${r%-dirty}
      if [ "$r" != "$base" ]; then printf '%s+' "''${base:0:7}"; else printf '%s' "''${base:0:7}"; fi
    }

    # ── gather ───────────────────────────────────────────────────────────────
    # The single source of truth for both the CLI and the web page. Probes every
    # host in parallel (bounding a run by one SSH timeout, not the sum) and emits
    # one TSV line per host:  host \t activated \t shortrev \t statusword
    # where statusword ∈ up-to-date | behind | reachable | unreachable.
    gather() {
      local hosts=()
      if [ "$#" -gt 0 ]; then
        hosts=("$@")
      else
        # shellcheck disable=SC2207
        hosts=($(flake_hosts)) || true
      fi
      [ "''${#hosts[@]}" -gt 0 ] || return 1

      local want; want=$(want_rev)
      local tmp; tmp=$(mktemp -d)
      local h
      for h in "''${hosts[@]}"; do probe_host "$h" >"$tmp/$h" & done
      wait

      local out d rev sw
      for h in "''${hosts[@]}"; do
        out=$(cat "$tmp/$h" 2>/dev/null)
        if [ -z "$out" ]; then
          printf '%s\t%s\t%s\t%s\n' "$h" "-" "-" "unreachable"; continue
        fi
        IFS=$'\t' read -r d rev <<<"$out"
        if [ -z "$rev" ]; then sw="reachable"
        elif [ -n "$want" ] && [ "$rev" = "$want" ]; then sw="up-to-date"
        else sw="behind"; fi
        printf '%s\t%s\t%s\t%s\n' "$h" "$d" "$(shortrev "$rev")" "$sw"
      done
      rm -rf "$tmp"
    }

    # ── cache ────────────────────────────────────────────────────────────────
    # gather()'s TSV, saved so a bare `fleet` can answer instantly from the last
    # poll instead of re-probing the whole estate. On meow the hourly fleet-web
    # timer keeps it warm; anywhere without a cache file, `fleet` just polls.
    cache_file() { printf '%s/fleet/status.tsv' "''${XDG_CACHE_HOME:-$HOME/.cache}"; }
    write_cache() {
      local f; f=$(cache_file)
      mkdir -p "$(dirname "$f")" 2>/dev/null || return 0
      printf '%s\n' "$1" >"$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f" 2>/dev/null || true
    }
    read_cache() { local f; f=$(cache_file); [ -f "$f" ] && cat "$f"; }
    # Fold a partial poll (e.g. `fleet status roar`, or the hosts just deployed)
    # into the cache: replace those hosts' lines, keep every other host as-is.
    merge_cache() {
      local new=$1 cur line h
      cur=$(read_cache)
      [ -n "$cur" ] || { write_cache "$new"; return; }
      local -A upd=()
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        h=''${line%%$'\t'*}; upd["$h"]=$line
      done <<<"$new"
      local out=""
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        h=''${line%%$'\t'*}
        if [ -n "''${upd[$h]:-}" ]; then out+="''${upd[$h]}"$'\n'; unset "upd[$h]"
        else out+="$line"$'\n'; fi
      done <<<"$cur"
      for h in "''${!upd[@]}"; do out+="''${upd[$h]}"$'\n'; done   # hosts new to the cache
      write_cache "''${out%$'\n'}"
    }
    cache_age() {
      local f secs; f=$(cache_file); [ -f "$f" ] || return 0
      secs=$(( $(date +%s) - $(stat -c %Y "$f") ))
      if   [ "$secs" -lt 90 ];   then printf 'just now'
      elif [ "$secs" -lt 3600 ]; then printf '%dm ago' "$((secs/60))"
      else printf '%dh%dm ago' "$((secs/3600))" "$(((secs%3600)/60))"; fi
    }

    # ── render (terminal) ─────────────────────────────────────────────────────
    render_table() {
      local data=$1 caption=$2
      local header rows="" h d rev sw color
      header=$(printf '%s%-9s %-19s %-9s %s%s' \
        "$a_muted" HOST ACTIVATED REV STATUS "$a_off")
      while IFS=$'\t' read -r h d rev sw; do
        case "$sw" in
          up-to-date)  color=$a_green;;
          behind)      color=$a_orange;;
          unreachable) color=$a_red;;
          *)           color=$a_muted;;
        esac
        rows+=$(printf '%-9s %-19s %-9s %s%s%s' \
          "$h" "$d" "$rev" "$color" "$sw" "$a_off")$'\n'
      done <<<"$data"

      local title body sub=""
      title=$(gum style --bold --foreground "$ink" --background "$green" " fleet ")
      [ -n "$caption" ] && sub=$'\n'"$a_muted$caption$a_off"
      body="$title$sub"$'\n\n'"$header"$'\n'"''${rows%$'\n'}"
      gum style --border rounded --border-foreground "$border" --padding "1 2" "$body"
    }

    # bare `fleet` — the cache if there is one (instant), else a live poll.
    cmd_default() {
      local data cap
      data=$(read_cache)
      if [ -n "$data" ]; then
        cap="cached $(cache_age) · 'fleet status' to refresh"
      else
        data=$(gather) || { echo "fleet: no hosts (set FLEET_FLAKE)" >&2; return 1; }
        write_cache "$data"; cap="live"
      fi
      render_table "$data" "$cap"
    }

    # `fleet status [host…]` — always a live poll; a full poll refreshes the cache.
    cmd_status() {
      local data; data=$(gather "$@") || {
        echo "fleet: no hosts (no checkout found; pass host names or set FLEET_FLAKE)" >&2
        return 1
      }
      # A full poll replaces the cache; a filtered one folds into it.
      if [ "$#" -eq 0 ]; then write_cache "$data"; else merge_cache "$data"; fi
      render_table "$data" "live"
    }

    # ── web (HTML, styled after azf.no) ──────────────────────────────────────
    # Reuses azf.no's own stylesheet + System-7 window chrome (it serves fonts
    # with CORS *, so the cross-origin link picks up IBM Plex too); a small
    # inline sheet adds the table and the one bit of colour. Emits to stdout;
    # the hourly timer (hosts/meow/fleet-web.nix) writes it to a file Caddy
    # serves at fleet.azf.no.
    cmd_web() {
      local data; data=$(gather) || { echo "fleet: no hosts" >&2; return 1; }
      write_cache "$data"   # keeps a bare `fleet` warm between hourly renders
      local now; now=$(date '+%Y-%m-%d %H:%M %Z')

      cat <<'HTMLHEAD'
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="900">
    <title>fleet · azf.no</title>
    <link rel="stylesheet" href="https://azf.no/style.css">
    <style>
      .window { max-width: 34rem; }
      .content { padding: 1.75rem 1.75rem 1.5rem; text-align: left; }
      h1 { text-align: center; margin-bottom: 1.5rem; }
      table { width: 100%; border-collapse: collapse;
              font-family: 'IBM Plex Mono', ui-monospace, monospace; font-size: .8125rem; }
      th { text-align: left; font-weight: 500; color: var(--muted);
           border-bottom: 1px solid var(--line); padding: 0 .75rem .4rem 0; }
      td { padding: .4rem .75rem .4rem 0; border-bottom: 1px solid var(--desk-a); }
      tr:last-child td { border-bottom: none; }
      .rev { color: var(--muted); }
      .s { font-weight: 500; }
      .up-to-date  { color: #2f6b54; }
      .behind      { color: #b5600a; }
      .unreachable { color: #b23b3b; }
      .reachable   { color: var(--muted); }
      .gen { margin-top: 1.5rem; font-size: .75rem; color: var(--muted); text-align: center; }
    </style>
    </head>
    <body>
      <main class="window">
        <div class="titlebar">
          <span class="close-box"></span>
          <span class="title">Fleet Status</span>
        </div>
        <div class="content">
          <h1>fleet</h1>
          <table>
            <thead><tr><th>host</th><th>activated</th><th>rev</th><th>status</th></tr></thead>
            <tbody>
    HTMLHEAD

      while IFS=$'\t' read -r h d rev sw; do
        printf '          <tr><td>%s</td><td>%s</td><td class="rev">%s</td><td class="s %s">%s</td></tr>\n' \
          "$h" "$d" "$rev" "$sw" "$sw"
      done <<<"$data"

      cat <<HTMLFOOT
            </tbody>
          </table>
          <p class="gen">updated $now · refreshes hourly</p>
        </div>
      </main>
    </body>
    </html>
    HTMLFOOT
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

      local h rc=0 deployed=()
      for h in "''${targets[@]}"; do
        if deploy_one "$h"; then
          gum style --foreground "$green" "✓ $h updated"; deployed+=("$h")
        else
          gum style --foreground "$red" "✗ $h failed"; rc=1
        fi
      done

      # Re-poll just the hosts we deployed and fold them into the cache, so a
      # bare `fleet` reflects the deploy immediately instead of the stale line.
      if [ "''${#deployed[@]}" -gt 0 ]; then
        merge_cache "$(gather "''${deployed[@]}")" || true
      fi
      return "$rc"
    }

    # ── dispatch ─────────────────────────────────────────────────────────────
    case "''${1:-default}" in
      default) cmd_default;;
      status) shift; cmd_status "$@";;
      web)    cmd_web;;
      update) shift; cmd_update "$@";;
      -h|--help|help)
        cat <<'USAGE'
    fleet                  status from the last poll (cached, instant)
    fleet status [host…]   live poll, optionally filtered
    fleet web              render the HTML status page (used by fleet.azf.no)
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
