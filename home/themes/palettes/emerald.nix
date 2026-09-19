# Shared application palette matching the Event Horizon shell.
{
  name = "emerald";
  displayName = "Event Horizon";

  base16 = {
    base00 = "091713";
    base01 = "11251e";
    base02 = "203c31";
    base03 = "36574a";
    base04 = "729888";
    base05 = "e4f4ea";
    base06 = "effaf3";
    base07 = "ffffff";
    base08 = "ef8c94";
    base09 = "e6ac84";
    base0A = "d5c58b";
    base0B = "83cfa9";
    base0C = "8fc7ce";
    base0D = "66cea3";
    base0E = "b7accf";
    base0F = "ad887c";
  };

  colors = {
    base = "#091713";
    mantle = "#07120f";
    crust = "#030b08";
    surface0 = "#162c23";
    surface1 = "#203c31";
    surface2 = "#36574a";
    overlay0 = "#4c7060";
    overlay1 = "#638574";
    overlay2 = "#80a190";

    text = "#e4f4ea";
    subtext0 = "#a1bfb0";
    subtext1 = "#bfd8ca";

    lavender = "#b7accf";
    blue = "#8fc7ce";
    sapphire = "#81b8c0";
    sky = "#a1d1d2";
    teal = "#77bda9";
    green = "#83cfa9";
    yellow = "#d5c58b";
    peach = "#e6ac84";
    maroon = "#bf7886";
    red = "#ef8c94";
    mauve = "#b7accf";
    pink = "#d4acc2";
    flamingo = "#dea2a0";
    rosewater = "#efd3bb";

    accent = "#66cea3";
    accentAlt = "#b3f7ce";

    success = "#83cfa9";
    warning = "#d5c58b";
    error = "#ef8c94";
    info = "#8fc7ce";
  };

  hyprland = {
    activeBorder = "rgba(66cea3ee) rgba(ef8c94ee) rgba(b7accfee) 45deg";
    inactiveBorder = "rgba(36574a88)";
    shadow = "rgba(030b08ee)";
  };

  waybar = {
    workspaceActive = "#66cea3";
    workspaceUrgent = "#ef8c94";
    workspaceHover = "#e6ac84";
    clock = "#e4f4ea";
    stats = "#b7accf";
    audio = "#efd3bb";
    bluetooth = "#8fc7ce";
    network = "#83cfa9";
    keyboard = "#a1bfb0";
    battery = "#83cfa9";
    batteryCharging = "#83cfa9";
    batteryWarning = "#d5c58b";
    batteryCritical = "#ef8c94";
    powerMenu = "#ef8c94";
    visualizer = "#66cea3";
    launcher = "#66cea3";
  };
}
