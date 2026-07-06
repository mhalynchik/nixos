{ config, pkgs, lib, vars, colors, ... }:

let
in
{
  home-manager.users.${vars.username} = {
    # Zed editor is installed via home.packages in home.nix

    # Zed settings.json with transparency and Catppuccin theme
    home.file.".config/zed/settings.json".text = builtins.toJSON {
      # Theme with transparency
      # Zed supports window transparency on supported platforms
      theme = {
        mode = "dark";
        dark = "Catppuccin Mocha";
        light = "Catppuccin Latte";
      };

      # Window transparency (0.0 - 1.0)
      # Note: Zed uses background_appearance for transparency
      window = {
        # 60% opacity
        opacity = 0.6;
        # Blur effect for transparency
        blur = true;
      };

      # UI settings
      ui_font_family = colors.fonts.monospace;
      ui_font_size = 14;

      # Buffer/Editor font
      buffer_font_family = colors.fonts.monospace;
      buffer_font_size = 14;
      buffer_line_height = "comfortable";

      # Editor settings
      cursor_blink = true;
      show_whitespaces = "selection";
      tab_size = 2;
      soft_wrap = "editor_width";
      format_on_save = "on";
      autosave = "on_focus_change";

      # Minimap
      minimap = {
        enabled = true;
        width = 80;
      };

      # Git integration
      git = {
        enabled = true;
        autoFetch = true;
        autoFetchInterval = 300;
        git_gutter = "tracked_files";
      };

      # Terminal
      terminal = {
        font_family = colors.fonts.monospace;
        font_size = 13;
        line_height = "comfortable";
        blinking = "on";
        shell = "system";
        working_directory = "current_project_directory";
        # Terminal transparency matches editor
        opacity = 0.6;
      };

      # Scrollbar
      scrollbar = {
        show = "auto";
        cursors = true;
        git_diff = true;
        search_results = true;
        selected_text = true;
      };

      # Tab bar
      tab_bar = {
        show_nav_history_buttons = true;
      };

      # Inlay hints
      inlay_hints = {
        enabled = true;
        show_type_hints = true;
        show_parameter_hints = true;
      };

      # Auto-bracket/quote
      use_autoclose = true;
      use_auto_surround = true;

      # File icons
      file_icons = "chevron"; # or "file_icons"

      # Project panel
      project_panel = {
        dock = "left";
        git_status = true;
        auto_fold_dirs = true;
      };

      # Outline panel
      outline_panel = {
        dock = "right";
      };

      # Collaboration panel
      collaboration_panel = {
        dock = "left";
      };

      # Notification panel
      notification_panel = {
        dock = "right";
      };

      # Chat panel
      chat_panel = {
        dock = "right";
      };

      # Assistant (AI) settings
      assistant = {
        version = "2";
        default_model = {
          provider = "anthropic";
          model = "claude-3-5-sonnet-latest";
        };
      };

      # Features
      features = {
        copilot = false;
        inline_completion_provider = "none";
      };

      # Telemetry
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      # Vim mode (optional)
      vim_mode = false;

      # Language-specific settings
      languages = {
        Nix = {
          tab_size = 2;
          format_on_save = "on";
        };
        Python = {
          tab_size = 4;
          format_on_save = "on";
        };
        JavaScript = {
          tab_size = 2;
          format_on_save = "on";
        };
        TypeScript = {
          tab_size = 2;
          format_on_save = "on";
        };
        Rust = {
          tab_size = 4;
          format_on_save = "on";
        };
      };

      # LSP settings
      lsp = {
        rust-analyzer = {
          initialization_options = {
            checkOnSave = {
              command = "clippy";
            };
          };
        };
      };
    };

    # Zed keymap
    home.file.".config/zed/keymap.json".text = builtins.toJSON [
      # Custom keybindings
      {
        context = "Editor";
        bindings = {
          "ctrl-shift-k" = "editor::DeleteLine";
          # "ctrl-shift-d" = "editor::DuplicateLine";
          "ctrl-/" = "editor::ToggleComments";
          "alt-up" = "editor::MoveLineUp";
          "alt-down" = "editor::MoveLineDown";
        };
      }
      {
        context = "Workspace";
        bindings = {
          "ctrl-shift-p" = "command_palette::Toggle";
          "ctrl-p" = "file_finder::Toggle";
          # "ctrl-shift-f" = "search::DeploySearch";
          "ctrl-`" = "terminal_panel::ToggleFocus";
          "ctrl-b" = "workspace::ToggleLeftDock";
        };
      }
    ];

    # Custom Catppuccin Mocha theme with transparency
    home.file.".config/zed/themes/catppuccin-mocha-transparent.json".text = builtins.toJSON {
      "$schema" = "https://zed.dev/schema/themes/v0.1.0.json";
      name = "Catppuccin Mocha Transparent";
      author = "Custom";
      themes = [
        {
          name = "Catppuccin Mocha Transparent";
          appearance = "dark";
          style = {
            # Background with 60% opacity representation
            # Zed themes don't support direct alpha, but we use darker colors
            background = colors.colors.base;
            "background.appearance" = "transparent";

            # Element backgrounds
            "element.background" = colors.colors.surface0;
            "element.hover" = colors.colors.surface1;
            "element.active" = colors.colors.surface2;
            "element.selected" = colors.colors.surface1;
            "element.disabled" = colors.colors.surface0;

            # Ghost element (lighter)
            "ghost_element.background" = "transparent";
            "ghost_element.hover" = colors.colors.surface0;
            "ghost_element.active" = colors.colors.surface1;
            "ghost_element.selected" = colors.colors.surface0;
            "ghost_element.disabled" = colors.colors.surface0;

            # Text
            text = colors.colors.text;
            "text.muted" = colors.colors.subtext0;
            "text.placeholder" = colors.colors.overlay0;
            "text.disabled" = colors.colors.overlay0;
            "text.accent" = colors.colors.accent;

            # Icons
            "icon" = colors.colors.text;
            "icon.muted" = colors.colors.subtext0;
            "icon.disabled" = colors.colors.overlay0;
            "icon.placeholder" = colors.colors.overlay0;
            "icon.accent" = colors.colors.accent;

            # Status bar
            "status_bar.background" = colors.colors.crust;

            # Title bar
            "title_bar.background" = colors.colors.crust;
            "title_bar.inactive_background" = colors.colors.mantle;

            # Toolbar
            "toolbar.background" = colors.colors.mantle;

            # Tab bar
            "tab_bar.background" = colors.colors.mantle;
            "tab.inactive_background" = colors.colors.mantle;
            "tab.active_background" = colors.colors.base;

            # Search
            "search.match_background" = "${colors.colors.accent}40";

            # Panel backgrounds
            "panel.background" = colors.colors.mantle;
            "panel.focused_border" = colors.colors.accent;

            # Pane
            "pane.focused_border" = colors.colors.accent;

            # Scrollbar
            "scrollbar.thumb.background" = "${colors.colors.surface2}80";
            "scrollbar.thumb.hover_background" = colors.colors.surface2;
            "scrollbar.thumb.border" = "transparent";
            "scrollbar.track.background" = "transparent";
            "scrollbar.track.border" = "transparent";

            # Editor
            "editor.background" = colors.colors.base;
            "editor.gutter.background" = colors.colors.base;
            "editor.subheader.background" = colors.colors.mantle;
            "editor.active_line.background" = "${colors.colors.surface0}80";
            "editor.highlighted_line.background" = colors.colors.surface0;
            "editor.line_number" = colors.colors.overlay0;
            "editor.active_line_number" = colors.colors.text;
            "editor.invisible" = colors.colors.surface2;
            "editor.wrap_guide" = colors.colors.surface0;
            "editor.active_wrap_guide" = colors.colors.surface1;
            "editor.document_highlight.read_background" = "${colors.colors.accent}20";
            "editor.document_highlight.write_background" = "${colors.colors.accent}30";

            # Terminal
            "terminal.background" = colors.colors.base;
            "terminal.foreground" = colors.colors.text;
            "terminal.bright_foreground" = colors.colors.text;
            "terminal.dim_foreground" = colors.colors.subtext0;
            "terminal.ansi.black" = colors.colors.surface1;
            "terminal.ansi.bright_black" = colors.colors.surface2;
            "terminal.ansi.red" = colors.colors.red;
            "terminal.ansi.bright_red" = colors.colors.red;
            "terminal.ansi.green" = colors.colors.green;
            "terminal.ansi.bright_green" = colors.colors.green;
            "terminal.ansi.yellow" = colors.colors.yellow;
            "terminal.ansi.bright_yellow" = colors.colors.yellow;
            "terminal.ansi.blue" = colors.colors.blue;
            "terminal.ansi.bright_blue" = colors.colors.blue;
            "terminal.ansi.magenta" = colors.colors.pink;
            "terminal.ansi.bright_magenta" = colors.colors.pink;
            "terminal.ansi.cyan" = colors.colors.teal;
            "terminal.ansi.bright_cyan" = colors.colors.teal;
            "terminal.ansi.white" = colors.colors.subtext1;
            "terminal.ansi.bright_white" = colors.colors.text;

            # Link
            "link_text.hover" = colors.colors.accent;

            # Borders
            border = colors.colors.surface0;
            "border.variant" = colors.colors.surface1;
            "border.focused" = colors.colors.accent;
            "border.selected" = colors.colors.accent;
            "border.transparent" = "transparent";
            "border.disabled" = colors.colors.surface0;

            # Elevated surface
            "elevated_surface.background" = colors.colors.surface0;

            # Surface
            "surface.background" = colors.colors.mantle;

            # Drop target
            "drop_target.background" = "${colors.colors.accent}30";

            # Players (collaboration cursors)
            "players" = [
              { cursor = colors.colors.accent; background = "${colors.colors.accent}30"; selection = "${colors.colors.accent}20"; }
              { cursor = colors.colors.green; background = "${colors.colors.green}30"; selection = "${colors.colors.green}20"; }
              { cursor = colors.colors.pink; background = "${colors.colors.pink}30"; selection = "${colors.colors.pink}20"; }
              { cursor = colors.colors.yellow; background = "${colors.colors.yellow}30"; selection = "${colors.colors.yellow}20"; }
              { cursor = colors.colors.red; background = "${colors.colors.red}30"; selection = "${colors.colors.red}20"; }
              { cursor = colors.colors.mauve; background = "${colors.colors.mauve}30"; selection = "${colors.colors.mauve}20"; }
              { cursor = colors.colors.teal; background = "${colors.colors.teal}30"; selection = "${colors.colors.teal}20"; }
              { cursor = colors.colors.peach; background = "${colors.colors.peach}30"; selection = "${colors.colors.peach}20"; }
            ];

            # Syntax highlighting
            "syntax" = {
              attribute = { color = colors.colors.yellow; };
              boolean = { color = colors.colors.peach; };
              comment = { color = colors.colors.overlay0; font_style = "italic"; };
              "comment.doc" = { color = colors.colors.overlay1; font_style = "italic"; };
              constant = { color = colors.colors.peach; };
              constructor = { color = colors.colors.sapphire; };
              embedded = { color = colors.colors.text; };
              emphasis = { font_style = "italic"; };
              "emphasis.strong" = { font_weight = 700; };
              enum = { color = colors.colors.teal; };
              function = { color = colors.colors.blue; };
              "function.method" = { color = colors.colors.blue; };
              "function.special.definition" = { color = colors.colors.blue; };
              hint = { color = colors.colors.teal; font_weight = 700; };
              keyword = { color = colors.colors.mauve; };
              label = { color = colors.colors.sapphire; };
              link_text = { color = colors.colors.blue; font_style = "italic"; };
              link_uri = { color = colors.colors.blue; };
              number = { color = colors.colors.peach; };
              operator = { color = colors.colors.sky; };
              predictive = { color = colors.colors.overlay1; font_style = "italic"; };
              preproc = { color = colors.colors.pink; };
              primary = { color = colors.colors.text; };
              property = { color = colors.colors.lavender; };
              punctuation = { color = colors.colors.overlay2; };
              "punctuation.bracket" = { color = colors.colors.overlay2; };
              "punctuation.delimiter" = { color = colors.colors.overlay2; };
              "punctuation.list_marker" = { color = colors.colors.overlay2; };
              "punctuation.special" = { color = colors.colors.sky; };
              string = { color = colors.colors.green; };
              "string.escape" = { color = colors.colors.pink; };
              "string.regex" = { color = colors.colors.peach; };
              "string.special" = { color = colors.colors.pink; };
              "string.special.symbol" = { color = colors.colors.flamingo; };
              tag = { color = colors.colors.mauve; };
              "text.literal" = { color = colors.colors.green; };
              title = { color = colors.colors.text; font_weight = 800; };
              type = { color = colors.colors.yellow; };
              "type.interface" = { color = colors.colors.yellow; };
              variable = { color = colors.colors.text; };
              "variable.special" = { color = colors.colors.maroon; };
              variant = { color = colors.colors.teal; };
            };
          };
        }
      ];
    };
  };
}
