{ config, pkgs, lib, ... }:

let
  # Ported from ~/.local/bin/tmux-grow-pane on the old setup. Bound to
  # `prefix =` (repeatable): grows the current pane horizontally, picking
  # the resize direction so edge panes grow inward.
  growPane = pkgs.writeShellScriptBin "tmux-grow-pane" ''
    pane_index=$(tmux display-message -p '#{pane_index}')
    pane_count=$(tmux display-message -p '#{window_panes}')

    if [ "$pane_index" -eq 0 ]; then
      tmux resize-pane -R 5
    elif [ "$pane_index" -eq $((pane_count - 1)) ]; then
      tmux resize-pane -L 5
    else
      tmux resize-pane -R 5
    fi
  '';
in
{
  programs.tmux = {
    enable = true;

    # Structured options replace the equivalent raw directives from the
    # old ~/.tmux.conf. This module is shared by every host (imported via
    # cli.nix). tmux-256color + the terminal-features lines below give
    # truecolor. sensibleOnTop is off to keep behaviour exactly as ported.
    prefix = "C-a";
    baseIndex = 1;
    focusEvents = true;
    keyMode = "emacs";
    terminal = "tmux-256color";
    sensibleOnTop = false;
    mouse = true;
    historyLimit = 50000;

    extraConfig = ''
      bind Escape copy-mode
      bind -T copy-mode j send -X halfpage-down
      bind -T copy-mode k send -X halfpage-up

      # enable copy function
      set -g allow-passthrough on

      # Pass extended keys (Shift+Enter, etc.) through to apps like Claude Code
      set -g extended-keys on
      set -as terminal-features 'xterm*:extkeys'
      set -as terminal-features 'ghostty*:extkeys'

      # Advertise 24-bit (truecolor) support so apps like Helix render full palettes
      set -as terminal-features 'xterm*:RGB'
      set -as terminal-features 'ghostty*:RGB'
      set-environment -g COLORTERM truecolor

      # reload config file
      bind r source-file ~/.config/tmux/tmux.conf

      # split panes using | and -
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      # grow current pane
      bind -r = run ${growPane}/bin/tmux-grow-pane

      # DESIGN TWEAKS

      # don't do anything when a 'bell' rings
      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence off
      setw -g monitor-activity off
      set -g bell-action none

      # clock mode
      setw -g clock-mode-colour yellow

      # copy mode
      setw -g mode-style 'fg=black bg=red bold'

      # panes
      set -g pane-border-style 'fg=red'
      set -g pane-active-border-style 'fg=yellow'

      # statusbar
      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'fg=red'

      set -g status-left '''
      set -g status-left-length 10

      set -g status-right-style 'fg=black bg=yellow'
      set -g status-right '%Y-%m-%d %H:%M '
      set -g status-right-length 50

      setw -g window-status-current-style 'fg=black bg=red'
      setw -g window-status-current-format ' #I #W #F '

      setw -g window-status-style 'fg=red bg=black'
      setw -g window-status-format ' #I #[fg=white]#W #[fg=yellow]#F '

      setw -g window-status-bell-style 'fg=yellow bg=red bold'

      # messages
      set -g message-style 'fg=yellow bg=red bold'

      # bases (dark) theme — overrides most of the styling above
      source-file ~/.config/tmux/bases.conf

      # Override bases.conf clock to show Oslo time
      set -g status-right-style 'bg=#1a1815'
      set -g status-right "#[fg=#4a9f82] #(TZ=Europe/Oslo date '+%%H:%%M')  #[fg=#e07800]#(TZ=Europe/Oslo date '+%%d %%b %%Y') "
    '';
  };

  # Theme files sourced from extraConfig. bases-light.conf ships too so a
  # later `source-file ~/.config/tmux/bases-light.conf` (or `bind r`-style
  # toggle) can switch palettes without leaving Nix.
  xdg.configFile."tmux/bases.conf".source = ../files/tmux/bases.conf;
  xdg.configFile."tmux/bases-light.conf".source = ../files/tmux/bases-light.conf;

  home.packages = [ growPane ];
}
