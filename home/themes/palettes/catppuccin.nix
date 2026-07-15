# Catppuccin Mocha Theme
# Original theme - soft, muted colors with purple/blue accents
{
  name = "catppuccin";
  displayName = "Catppuccin Mocha";

  # Base16 scheme for Stylix
  base16 = {
    base00 = "1e1e2e"; # base
    base01 = "181825"; # mantle
    base02 = "313244"; # surface0
    base03 = "45475a"; # surface1
    base04 = "585b70"; # surface2
    base05 = "cdd6f4"; # text
    base06 = "f5e0dc"; # rosewater
    base07 = "b4befe"; # lavender
    base08 = "f38ba8"; # red
    base09 = "fab387"; # peach
    base0A = "f9e2af"; # yellow
    base0B = "a6e3a1"; # green
    base0C = "94e2d5"; # teal
    base0D = "89b4fa"; # blue
    base0E = "cba6f7"; # mauve
    base0F = "f2cdcd"; # flamingo
  };

  # Extended color palette
  colors = {
    # Base colors
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";
    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";

    # Text colors
    text = "#cdd6f4";
    subtext0 = "#a6adc8";
    subtext1 = "#bac2de";

    # Accent colors
    lavender = "#b4befe";
    blue = "#89b4fa";
    sapphire = "#74c7ec";
    sky = "#89dceb";
    teal = "#94e2d5";
    green = "#a6e3a1";
    yellow = "#f9e2af";
    peach = "#fab387";
    maroon = "#eba0ac";
    red = "#f38ba8";
    mauve = "#cba6f7";
    pink = "#f5c2e7";
    flamingo = "#f2cdcd";
    rosewater = "#f5e0dc";

    # Primary accent (used for highlights, borders)
    accent = "#cba6f7";
    accentAlt = "#b4befe";

    # Semantic colors
    success = "#a6e3a1";
    warning = "#f9e2af";
    error = "#f38ba8";
    info = "#89b4fa";
  };

  # Hyprland-specific
  hyprland = {
    activeBorder = "rgba(cba6f7ee) rgba(89b4faee) rgba(94e2d5ee) 45deg";
    inactiveBorder = "rgba(45475a88)";
    shadow = "rgba(1a1a1aee)";
  };

  # Waybar-specific colors (Catppuccin Mocha / HyDE)
  waybar = {
    workspaceActive = "#cba6f7";
    workspaceUrgent = "#f38ba8";
    workspaceHover = "#b4befe";
    clock = "#cdd6f4";
    stats = "#94e2d5";
    audio = "#f5e0dc";
    bluetooth = "#89b4fa";
    network = "#a6e3a1";
    keyboard = "#89dceb";
    battery = "#94e2d5";
    batteryCharging = "#a6e3a1";
    batteryWarning = "#fab387";
    batteryCritical = "#f38ba8";
    powerMenu = "#f38ba8";
    visualizer = "#89dceb";
    launcher = "#cba6f7";
  };
}








