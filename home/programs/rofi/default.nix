{ config, pkgs, vars, colors, ... }:

let
  rgba = colors.toRgba;
in
{
  home-manager.users.${vars.username} = {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;
      terminal = "${pkgs.kitty}/bin/kitty";
      # Theme is set via home.file below for dynamic color support
      theme = "theme";  # Will look for ~/.config/rofi/theme.rasi
      plugins = [ pkgs.rofi-games ];
      extraConfig = {
        modi = "drun,run,filebrowser,window,games";
        show-icons = true;
        display-drun = "Apps";
        display-run = "Run";
        display-filebrowser = "Files";
        display-window = "Windows";
        drun-display-format = "{name}";
        window-format = "{w} · {c} · {t}";
      };
    };

    # Rofi theme with 60% transparency
    home.file.".config/rofi/theme.rasi".text = ''
      /*****----- Configuration -----*****/
      configuration {
          modi:                       "drun,run,filebrowser,window";
          show-icons:                 true;
          display-drun:               "APPS";
          display-run:                "RUN";
          display-filebrowser:        "FILES";
          display-window:             "WINDOW";
          drun-display-format:        "{name}";
          window-format:              "{w} · {c} · {t}";
      }

      /*****----- Global Properties -----*****/
      /* Theme: ${colors.displayName} with 60% transparency */
      * {
          font:                        "${colors.fonts.monospace} 10";
          background:                  ${rgba colors.colors.base 0.6};
          background-alt:              ${rgba colors.colors.surface0 0.7};
          foreground:                  ${colors.colors.text};
          selected:                    ${colors.colors.accent};
          active:                      ${colors.colors.accentAlt};
          urgent:                      ${colors.colors.red};
      }

      /*****----- Main Window -----*****/
      window {
          transparency:                "real";
          location:                    center;
          anchor:                      center;
          fullscreen:                  false;
          width:                       600px;
          x-offset:                    0px;
          y-offset:                    0px;
          enabled:                     true;
          border-radius:               12px;
          border:                      2px solid;
          border-color:                @selected;
          cursor:                      "default";
          background-color:            @background;
      }

      /*****----- Main Box -----*****/
      mainbox {
          enabled:                     true;
          spacing:                     10px;
          padding:                     20px;
          background-color:            transparent;
          orientation:                 vertical;
          children:                    [ "inputbar", "message", "listview", "mode-switcher" ];
      }

      /*****----- Inputbar -----*****/
      inputbar {
          enabled:                     true;
          spacing:                     10px;
          padding:                     12px 16px;
          border-radius:               8px;
          background-color:            @background-alt;
          text-color:                  @foreground;
          children:                    [ "textbox-prompt-colon", "entry" ];
      }

      textbox-prompt-colon {
          enabled:                     true;
          expand:                      false;
          str:                         " ";
          background-color:            inherit;
          text-color:                  @selected;
      }

      entry {
          enabled:                     true;
          background-color:            inherit;
          text-color:                  inherit;
          cursor:                      text;
          placeholder:                 "Search...";
          placeholder-color:           ${colors.colors.overlay0};
      }

      /*****----- Mode Switcher -----*****/
      mode-switcher {
          enabled:                     true;
          spacing:                     10px;
          background-color:            transparent;
          text-color:                  @foreground;
      }

      button {
          padding:                     10px 15px;
          border-radius:               8px;
          background-color:            @background-alt;
          text-color:                  inherit;
          cursor:                      pointer;
      }

      button selected {
          background-color:            @selected;
          text-color:                  @background;
      }

      /*****----- Listview -----*****/
      listview {
          enabled:                     true;
          columns:                     1;
          lines:                       8;
          cycle:                       true;
          dynamic:                     true;
          scrollbar:                   false;
          layout:                      vertical;
          reverse:                     false;
          fixed-height:                true;
          fixed-columns:               true;
          spacing:                     5px;
          background-color:            transparent;
          text-color:                  @foreground;
          cursor:                      "default";
      }

      /*****----- Elements -----*****/
      element {
          enabled:                     true;
          spacing:                     10px;
          padding:                     8px 12px;
          border-radius:               8px;
          background-color:            transparent;
          text-color:                  @foreground;
          cursor:                      pointer;
      }

      element normal.normal {
          background-color:            inherit;
          text-color:                  inherit;
      }

      element normal.urgent {
          background-color:            @urgent;
          text-color:                  @background;
      }

      element normal.active {
          background-color:            @active;
          text-color:                  @background;
      }

      element selected.normal {
          background-color:            @selected;
          text-color:                  @background;
      }

      element selected.urgent {
          background-color:            @urgent;
          text-color:                  @background;
      }

      element selected.active {
          background-color:            @active;
          text-color:                  @background;
      }

      element-icon {
          background-color:            transparent;
          text-color:                  inherit;
          size:                        24px;
          cursor:                      inherit;
      }

      element-text {
          background-color:            transparent;
          text-color:                  inherit;
          cursor:                      inherit;
          vertical-align:              0.5;
          horizontal-align:            0.0;
      }

      /*****----- Message -----*****/
      message {
          background-color:            transparent;
      }

      textbox {
          padding:                     12px;
          border-radius:               8px;
          background-color:            @background-alt;
          text-color:                  @foreground;
          vertical-align:              0.5;
          horizontal-align:            0.0;
      }

      error-message {
          padding:                     12px;
          border-radius:               8px;
          background-color:            @urgent;
          text-color:                  @background;
      }
    '';
  };
}
