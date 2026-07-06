{ config, pkgs, vars, colors, ... }:

let
  c = colors.colors;
in
{
  home-manager.users.${vars.username} = {
    home.file.".config/cava/config".text = ''
      # CAVA Configuration - Theme: ${colors.displayName}

      [general]
      framerate = 60
      autosens = 1
      sensitivity = 100
      bars = 0
      bar_width = 2
      bar_spacing = 1

      [input]
      method = pulse
      source = auto

      [output]
      method = ncurses
      channels = stereo

      [color]
      gradient = 1
      gradient_count = 6
      gradient_color_1 = '${c.accent}'
      gradient_color_2 = '${c.blue}'
      gradient_color_3 = '${c.mauve}'
      gradient_color_4 = '${c.pink}'
      gradient_color_5 = '${c.peach}'
      gradient_color_6 = '${c.red}'

      [smoothing]
      noise_reduction = 0.77
    '';

    # Config for waybar integration
    home.file.".config/cava/config-waybar".text = ''
      # CAVA Configuration for Waybar

      [general]
      framerate = 60
      autosens = 1
      bars = 12
      bar_width = 1
      bar_spacing = 0
      sleep_timer = 10

      [input]
      method = pulse
      source = auto

      [output]
      method = raw
      data_format = ascii
      ascii_max_range = 7
      raw_target = /dev/stdout
      bar_delimiter = 32
      frame_delimiter = 10

      [color]
      gradient = 0

      [smoothing]
      noise_reduction = 0.77
    '';
  };
}
