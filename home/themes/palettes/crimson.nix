# Crimson Night Theme
# High contrast theme with red and gray tones
# Inspired by blood moon aesthetics
{
  name = "crimson";
  displayName = "Crimson Night";

  # Base16 scheme for Stylix
  base16 = {
    base00 = "0a0a0a"; # background - deep black
    base01 = "121212"; # lighter bg
    base02 = "1f1f1f"; # selection bg
    base03 = "2d2d2d"; # comments
    base04 = "4a4a4a"; # dark gray
    base05 = "e8e8e8"; # foreground - bright white
    base06 = "f5f5f5"; # light foreground
    base07 = "ffffff"; # bright white
    base08 = "ff3b3b"; # red - errors, important
    base09 = "ff6b4a"; # orange-red
    base0A = "ffaa5c"; # muted orange/gold
    base0B = "7d9e7d"; # muted sage green
    base0C = "8a9ba8"; # steel blue-gray
    base0D = "dc2626"; # crimson red - primary
    base0E = "be3455"; # deep rose
    base0F = "6b4a4a"; # muted maroon
  };

  # Extended color palette
  colors = {
    # Base colors (grays)
    base = "#0a0a0a";
    mantle = "#050505";
    crust = "#000000";
    surface0 = "#141414";
    surface1 = "#1f1f1f";
    surface2 = "#2d2d2d";
    overlay0 = "#404040";
    overlay1 = "#525252";
    overlay2 = "#6b6b6b";

    # Text colors
    text = "#e8e8e8";
    subtext0 = "#a3a3a3";
    subtext1 = "#c4c4c4";

    # Accent colors (reds and complementary)
    lavender = "#be3455";
    blue = "#8a9ba8";
    sapphire = "#6b8a9a";
    sky = "#7a9aa8";
    teal = "#5a8a7a";
    green = "#7d9e7d";
    yellow = "#ffaa5c";
    peach = "#ff6b4a";
    maroon = "#991b1b";
    red = "#ff3b3b";
    mauve = "#be3455";
    pink = "#f472b6";
    flamingo = "#e57373";
    rosewater = "#ffc0c0";

    # Primary accent
    accent = "#dc2626";
    accentAlt = "#ff4444";

    # Semantic colors
    success = "#7d9e7d";
    warning = "#ffaa5c";
    error = "#ff3b3b";
    info = "#8a9ba8";
  };

  # Hyprland-specific
  hyprland = {
    activeBorder = "rgba(dc2626ee) rgba(ff3b3bee) rgba(be3455ee) 45deg";
    inactiveBorder = "rgba(2d2d2d88)";
    shadow = "rgba(000000ee)";
  };

  # Waybar-specific colors
  waybar = {
    workspaceActive = "#dc2626";
    workspaceUrgent = "#ff3b3b";
    workspaceHover = "#ff6b4a";
    clock = "#e8e8e8";
    stats = "#be3455";
    audio = "#ffc0c0";
    bluetooth = "#8a9ba8";
    network = "#7d9e7d";
    keyboard = "#a3a3a3";
    battery = "#7d9e7d";
    batteryCharging = "#7d9e7d";
    batteryWarning = "#ffaa5c";
    batteryCritical = "#ff3b3b";
    powerMenu = "#ff3b3b";
    visualizer = "#dc2626";
    launcher = "#dc2626";
  };
}








