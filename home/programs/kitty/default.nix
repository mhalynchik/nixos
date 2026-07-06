{ config, pkgs, vars, colors, ... }:

let
  c = colors.colors;
in
{
  home-manager.users.${vars.username} = {
    programs.kitty = {
      enable = true;

      font = {
        name = "JetBrainsMono Nerd Font";
        size = 14;
      };

      settings = {
        # Shell
        shell = "zsh";

        # Window
        confirm_os_window_close = 0;
        window_padding_width = 10;
        background_opacity = "0.6";
        dynamic_background_opacity = true;

        # Cursor
        cursor_shape = "beam";
        cursor_blink_interval = "0.5";

        # Scrollback
        scrollback_lines = 10000;

        # Mouse
        mouse_hide_wait = 3;
        url_style = "curly";

        # Bell
        enable_audio_bell = false;
        visual_bell_duration = "0.0";

        # Tab bar
        tab_bar_edge = "bottom";
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";

        # The basic colors - dynamic from theme
        foreground = c.text;
        background = c.base;
        selection_foreground = c.base;
        selection_background = c.rosewater;

        # Cursor colors
        cursor = c.rosewater;
        cursor_text_color = c.base;

        # URL underline color when hovering with mouse
        url_color = c.rosewater;

        # Kitty window border colors
        active_border_color = c.lavender;
        inactive_border_color = c.overlay0;
        bell_border_color = c.yellow;

        # OS Window titlebar colors
        wayland_titlebar_color = "system";

        # Tab bar colors
        active_tab_foreground = c.crust;
        active_tab_background = c.accent;
        inactive_tab_foreground = c.text;
        inactive_tab_background = c.mantle;
        tab_bar_background = c.crust;

        # Colors for marks
        mark1_foreground = c.base;
        mark1_background = c.lavender;
        mark2_foreground = c.base;
        mark2_background = c.mauve;
        mark3_foreground = c.base;
        mark3_background = c.sapphire;

        # The 16 terminal colors - dynamic from theme
        # black
        color0 = c.surface1;
        color8 = c.surface2;

        # red
        color1 = c.red;
        color9 = c.red;

        # green
        color2 = c.green;
        color10 = c.green;

        # yellow
        color3 = c.yellow;
        color11 = c.yellow;

        # blue
        color4 = c.blue;
        color12 = c.blue;

        # magenta
        color5 = c.pink;
        color13 = c.pink;

        # cyan
        color6 = c.teal;
        color14 = c.teal;

        # white
        color7 = c.subtext1;
        color15 = c.subtext0;
      };

      keybindings = {
        "ctrl+shift+t" = "new_tab";
        "ctrl+shift+w" = "close_tab";
        "ctrl+shift+right" = "next_tab";
        "ctrl+shift+left" = "previous_tab";
        "ctrl+shift+enter" = "new_window";
        "ctrl+shift+n" = "new_os_window";
        "ctrl+shift+c" = "copy_to_clipboard";
        "ctrl+shift+v" = "paste_from_clipboard";
        "ctrl+shift+equal" = "change_font_size all +2.0";
        "ctrl+shift+minus" = "change_font_size all -2.0";
        "ctrl+shift+0" = "change_font_size all 0";
        # Background opacity controls (only background, not text)
        "alt+shift+equal" = "set_background_opacity +0.05";      # Alt+Shift+= increase opacity
        "alt+shift+minus" = "set_background_opacity -0.05";      # Alt+Shift+- decrease opacity
        "alt+shift+1" = "set_background_opacity 1";              # Alt+Shift+1 fully opaque
        "alt+shift+0" = "set_background_opacity default";        # Alt+Shift+0 default (60%)
      };
    };
  };
}
