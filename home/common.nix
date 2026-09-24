{
  pkgs,
  lib,
  config,
  ...
}:
{
  home = {
    username = "silvio";
    stateVersion = "26.05";

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.cargo/bin"
      "$HOME/go/bin"
    ];

    packages = with pkgs; [
      age
      bat
      claude-code
      direnv
      eza
      fzf
      iperf3
      lazygit
      nixfmt
      nixos-rebuild
      ookla-speedtest
      restic
      ripgrep
      rsync
      sops
      ssh-to-age
      stow
      tmux
      tree
    ];
  };

  programs = {

    direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    neovim = {
      enable = true;
      defaultEditor = true; # Sets $EDITOR and $VISUAL to nvim
      viAlias = true; # Aliases `vi` to `nvim`
      vimAlias = true; # Aliases `vim` to `nvim`

      plugins = with pkgs.vimPlugins; [
        solarized-nvim
      ];

      initLua = ''
        vim.opt.termguicolors = true
        vim.opt.background = "light" -- or "dark"

        -- Optional configuration variables for shaunsingh/solarized.nvim:
        -- vim.g.solarized_italic_comments = true
        -- vim.g.solarized_italic_keywords = true
        -- vim.g.solarized_italic_functions = true
        -- vim.g.solarized_italic_variables = false
        -- vim.g.solarized_contrast = true
        -- vim.g.solarized_borders = false
        -- vim.g.solarized_disable_background = false

        vim.cmd.colorscheme("solarized")
      '';
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          AddKeysToAgent = true;
        };
      };
      includes = [
        "/run/secrets/ssh_config"
      ];
    };

    tmux = {
      enable = true;

      # Core bindings & settings
      prefix = "C-a";
      baseIndex = 1;
      mouse = true;
      keyMode = "vi";

      # Eliminates delay when pressing Esc in Neovim
      escapeTime = 0;

      # Large scrollback buffer (default is often too small at 2000)
      historyLimit = 10000;

      # Tell tmux outside terminal supports 256 colors
      terminal = "tmux-256color";

      plugins = with pkgs.tmuxPlugins; [
        yank
      ];

      extraConfig = ''
        # Keep pane numbering aligned with window numbering (1-based)
        setw -g pane-base-index 1
        set -g renumber-windows on

        bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

        # Enable truecolor (24-bit) passthrough
        set -ag terminal-overrides ",$TERM:RGB"
        set -ag terminal-overrides ",alacritty:RGB,xterm-256color:RGB,konsole:RGB"

        # Open new panes and windows in the current working directory
        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
        bind c new-window -c "#{pane_current_path}"

        # Intuitive pane splits (| and -)
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # Vim-like pane navigation (Prefix + h/j/k/l)
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Vim-style selection & copy in copy-mode
        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi y send -X copy-selection-and-cancel

        # 1. Tell tmux-yank what action to use
        set -g @yank_action 'copy-pipe'
        set -g @yank_with_mouse off

        # 2. Explicitly override the binding after everything settles
        # Using wl-copy on Linux/Wayland or pbcopy on macOS
        bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X stop-selection
        bind -T copy-mode MouseDragEnd1Pane send-keys -X stop-selection  
      '';
    };

    starship = {
      enable = true;
      enableZshIntegration = true;

      settings = {
        directory = {
          style = "bold #268bd2";
        };
        nix_shell = {
          symbol = "❄️ ";
          format = "via [$symbol$state]($style) ";
        };
      };
    };

    fzf = {
      enable = true;

      # Use fzf in zsh (Ctrl-r, Ctrl-t)
      enableZshIntegration = true;

      # Optional: use fd/ripgrep for fast, hidden-file-aware file searching
      defaultCommand = "${pkgs.ripgrep}/bin/rg --files --hidden --glob '!.git'";
    };

    # Universal shell configuration
    zsh = {

      enable = true;

      shellAliases = {
        ls = "eza";
        cat = "bat";
      };
      defaultKeymap = "viins";

      # History configuration
      history = {
        size = 10000;
        save = 10000;
        path = "${config.home.homeDirectory}/.histfile";

        # Don't save commands starting with space
        ignoreSpace = true;
      };

      # Built-in setopt mappings
      enableCompletion = true;

      # Options without a direct structured key go into setOptions or unsetopt
      setOptions = [
        "EXTENDED_GLOB" # setopt extendedglob
        "NOMATCH" # setopt nomatch
        "NOTIFY" # setopt notify
      ];

      initContent = ''
        # don't beep
        unsetopt beep

        # More responsive timeout
        KEYTIMEOUT=15

        # Maps 'jk' to escape back to normal mode
        bindkey -M viins 'jk' vi-cmd-mode

        # Intercept bare 'tmux' commands to attach or create
        tmux() {
          if [ $# -eq 0 ]; then
            command tmux new-session -A -s main
          else
            command tmux "$@"
          fi
        }
      '';
    };

    git = {
      enable = true;
      settings.user = {
        name = "Silvio";
        email = "sboehler@noreply.users.github.com";
      };
    };
  };
}
