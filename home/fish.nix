{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.fnm ];

  programs.fish = {
    enable = true;

    plugins = [
      { name = "pure"; src = pkgs.fishPlugins.pure.src; }
    ];

    # `rebuild` — rebuild the current host from the flake, anywhere, on any OS.
    # Lives in home-manager (not a NixOS module) so it works identically on
    # NixOS and nix-darwin. ~/.nixcfg is the consistent checkout path on both;
    # the config attr is left implicit so nixos-rebuild/darwin-rebuild pick the
    # entry matching this machine's hostname. Extra args pass through, e.g.
    # `rebuild boot` or `rebuild test`.
    functions.rebuild = ''
      set -l action $argv
      test (count $argv) -eq 0; and set action switch
      switch (uname)
        case Darwin
          sudo darwin-rebuild $action --flake ~/.nixcfg
        case '*'
          sudo nixos-rebuild $action --flake ~/.nixcfg
      end
    '';

    # fish_greeting is defined system-wide in modules/motd.nix so every user
    # gets the motd, not just this one.

    interactiveShellInit = ''
      # fnm — Node version manager shell integration
      fnm env --shell fish | source


      # bases theme (dark) — syntax-highlight + pager colors
      set -g fish_color_normal ede8de
      set -g fish_color_command 4a9f82
      set -g fish_color_keyword 4a9f82 --bold
      set -g fish_color_quote e07800
      set -g fish_color_redirection 5a8fcc
      set -g fish_color_end 857e75
      set -g fish_color_error d95050
      set -g fish_color_param ede8de
      set -g fish_color_valid_path ede8de --underline
      set -g fish_color_option ede8de
      set -g fish_color_comment 4a4640 --italics
      set -g fish_color_operator e07800
      set -g fish_color_escape 57b090
      set -g fish_color_match 4a9f82 --underline
      set -g fish_color_autosuggestion 4a4640
      set -g fish_color_history_current --bold
      set -g fish_color_selection ede8de --background=3a3630
      set -g fish_color_search_match 141210 --background=e07800
      set -g fish_color_cancel d95050 --reverse
      set -g fish_color_cwd 4a9f82
      set -g fish_color_cwd_root d95050
      set -g fish_color_user 4a9f82
      set -g fish_color_host 857e75
      set -g fish_color_host_remote e07800
      set -g fish_color_status d95050
      set -g fish_color_bind ede8de

      set -g fish_pager_color_progress 141210 --background=4a9f82
      set -g fish_pager_color_background --background=1a1815
      set -g fish_pager_color_prefix ede8de --bold --underline
      set -g fish_pager_color_completion ede8de
      set -g fish_pager_color_description 857e75 --italics
      set -g fish_pager_color_selected_background --background=201e1a
      set -g fish_pager_color_selected_prefix 4a9f82 --bold --underline
      set -g fish_pager_color_selected_completion ede8de --bold
      set -g fish_pager_color_selected_description 857e75 --italics
      set -g fish_pager_color_secondary_prefix ede8de --underline
      set -g fish_pager_color_secondary_completion ede8de
      set -g fish_pager_color_secondary_description 4a4640 --italics

      # pure prompt — migrated from fish_variables
      set -g pure_begin_prompt_with_current_directory true
      set -g pure_check_for_new_release false
      set -g pure_color_at_sign pure_color_mute
      set -g pure_color_aws_profile pure_color_warning
      set -g pure_color_command_duration pure_color_warning
      set -g pure_color_current_directory pure_color_primary
      set -g pure_color_danger red
      set -g pure_color_dark black
      set -g pure_color_exit_status pure_color_danger
      set -g pure_color_git_branch pure_color_mute
      set -g pure_color_git_dirty pure_color_mute
      set -g pure_color_git_stash pure_color_info
      set -g pure_color_git_unpulled_commits pure_color_info
      set -g pure_color_git_unpushed_commits pure_color_info
      set -g pure_color_hostname pure_color_mute
      set -g pure_color_info cyan
      set -g pure_color_jobs pure_color_normal
      set -g pure_color_k8s_context pure_color_success
      set -g pure_color_k8s_namespace pure_color_primary
      set -g pure_color_k8s_prefix pure_color_info
      set -g pure_color_light white
      set -g pure_color_mute brblack
      set -g pure_color_nixdevshell_prefix pure_color_info
      set -g pure_color_nixdevshell_symbol pure_color_mute
      set -g pure_color_normal normal
      set -g pure_color_prefix_root_prompt pure_color_danger
      set -g pure_color_primary blue
      set -g pure_color_prompt_on_error pure_color_danger
      set -g pure_color_prompt_on_success pure_color_success
      set -g pure_color_success magenta
      set -g pure_color_system_time pure_color_mute
      set -g pure_color_username_normal pure_color_mute
      set -g pure_color_username_root pure_color_light
      set -g pure_color_virtualenv pure_color_mute
      set -g pure_color_warning yellow
      set -g pure_convert_exit_status_to_signal false
      set -g pure_enable_aws_profile true
      set -g pure_enable_container_detection true
      set -g pure_enable_git true
      set -g pure_enable_k8s false
      set -g pure_enable_nixdevshell false
      set -g pure_enable_single_line_prompt false
      set -g pure_enable_virtualenv true
      set -g pure_reverse_prompt_symbol_in_vimode true
      set -g pure_separate_prompt_on_error false
      set -g pure_shorten_prompt_current_directory_length 0
      set -g pure_shorten_window_title_current_directory_length 0
      set -g pure_show_exit_status false
      set -g pure_show_jobs false
      set -g pure_show_numbered_git_indicator false
      set -g pure_show_prefix_root_prompt false
      set -g pure_show_subsecond_command_duration false
      set -g pure_show_system_time false
      set -g pure_symbol_exit_status_prefix '|'
      set -g pure_symbol_exit_status_separator '|'
      set -g pure_symbol_git_dirty '*'
      set -g pure_symbol_git_stash ≡
      set -g pure_symbol_git_unpulled_commits ⇣
      set -g pure_symbol_git_unpushed_commits ⇡
      set -g pure_symbol_k8s_prefix ☸
      set -g pure_symbol_nixdevshell_prefix ❄️
      set -g pure_symbol_prefix_root_prompt '#'
      set -g pure_symbol_prompt ❯
      set -g pure_symbol_reverse_prompt ❮
      set -g pure_symbol_title_bar_separator '-'
      set -g pure_system_time_format '+%T'
      set -g pure_threshold_command_duration 5
      set -g pure_truncate_prompt_current_directory_keeps -1
      set -g pure_truncate_window_title_current_directory_keeps -1
    '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
  ];
}
