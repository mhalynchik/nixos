# HyDE Gallery -> internal color interface adapter.
#
# This adapter ONLY parses allowlisted color fields from a theme's kitty.theme
# file (a plain "key  #RRGGBB" list). It never sources or executes *.theme,
# *.dcol, justfile or any command from theme headers. Every parsed value is
# validated as 6-digit hex; a missing mandatory field aborts evaluation.
{ lib }:

let
  _lines = content: lib.splitString "\n" content;

  # Match a single "  <key>   #RRGGBB[AA]" line. Anchored at line start so
  # "color1" never matches "color11" and "background" never matches
  # "selection_background".
  _matchHex = key: line:
    let
      m = builtins.match "[[:space:]]*${key}[[:space:]]+#?([0-9A-Fa-f]{6})[0-9A-Fa-f]*.*" line;
    in
      if m == null then null else builtins.head m;

  _lookup = content: key:
    let
      hits = lib.filter (v: v != null) (map (_matchHex key) (_lines content));
    in
      if hits == [ ] then null else lib.toLower (builtins.head hits);

  _require = themePath: content: key:
    let
      value = _lookup content key;
    in
      if value == null then
        builtins.throw
          "HyDE Gallery adapter: mandatory color '${key}' not found in ${themePath}/kitty.theme"
      else if builtins.match "[0-9a-f]{6}" value == null then
        builtins.throw
          "HyDE Gallery adapter: color '${key}' in ${themePath}/kitty.theme is not 6-digit hex (${value})"
      else
        value;
in
{
  # Produce a palette in the exact shape of the builtin palettes
  # (name, displayName, base16, colors, hyprland, waybar). fonts stay shared in
  # colors.nix, so they are intentionally not provided here.
  palette = { name, displayName, themePath }:
    let
      kitty = builtins.readFile "${themePath}/kitty.theme";
      get = _require themePath kitty;

      # --- allowlisted parsed fields (bare 6-hex, lowercased) ---
      bg = get "background";
      fg = get "foreground";
      sel = get "selection_background";
      urlc = get "url_color";
      activeBorder = get "active_border_color";
      inactiveBorder = get "inactive_border_color";
      inactiveTab = get "inactive_tab_background";
      tabBar = get "tab_bar_background";
      c0 = get "color0";
      c1 = get "color1";
      c2 = get "color2";
      c3 = get "color3";
      c4 = get "color4";
      c5 = get "color5";
      c6 = get "color6";
      c7 = get "color7";
      c8 = get "color8";
      c9 = get "color9";
      c15 = get "color15";

      h = v: "#${v}";
    in
    {
      inherit name displayName;

      # base16 mapped from the ANSI palette. Slots the theme does not define
      # distinctly (base03/base04 grays, base09 peach, base0F flamingo) are
      # approximated from the nearest parsed field and documented inline.
      base16 = {
        base00 = bg; # base
        base01 = inactiveTab; # mantle
        base02 = c0; # surface0 (ANSI black)
        base03 = inactiveBorder; # surface1 (approx: no distinct field)
        base04 = c8; # surface2 (approx: bright black)
        base05 = fg; # text
        base06 = sel; # rosewater
        base07 = urlc; # lavender
        base08 = c1; # red
        base09 = c9; # peach (approx: bright red)
        base0A = c3; # yellow
        base0B = c2; # green
        base0C = c6; # teal
        base0D = c4; # blue
        base0E = activeBorder; # mauve (accent)
        base0F = c5; # flamingo (approx: magenta/pink)
      };

      colors = {
        base = h bg;
        mantle = h inactiveTab;
        crust = h tabBar;
        surface0 = h c0;
        surface1 = h inactiveBorder; # approx
        surface2 = h c8; # approx
        overlay0 = h inactiveBorder; # approx
        overlay1 = h inactiveBorder; # approx
        overlay2 = h c15; # approx

        text = h fg;
        subtext0 = h c15;
        subtext1 = h c7;

        lavender = h urlc;
        blue = h c4;
        sapphire = h c6; # approx: cyan family
        sky = h c6; # approx: cyan family
        teal = h c6;
        green = h c2;
        yellow = h c3;
        peach = h c9; # approx
        maroon = h c1; # approx: red family
        red = h c1;
        mauve = h activeBorder;
        pink = h c5;
        flamingo = h sel; # approx
        rosewater = h sel;

        accent = h activeBorder;
        accentAlt = h urlc;

        success = h c2;
        warning = h c3;
        error = h c1;
        info = h c4;
      };

      hyprland = {
        activeBorder = "rgba(${activeBorder}ee) rgba(${c4}ee) rgba(${c6}ee) 45deg";
        inactiveBorder = "rgba(${c0}88)";
        shadow = "rgba(${tabBar}ee)";
      };

      waybar = {
        workspaceActive = h activeBorder;
        workspaceUrgent = h c1;
        workspaceHover = h urlc;
        clock = h fg;
        stats = h c6;
        audio = h sel;
        bluetooth = h c4;
        network = h c2;
        keyboard = h c6;
        battery = h c6;
        batteryCharging = h c2;
        batteryWarning = h c9;
        batteryCritical = h c1;
        powerMenu = h c1;
        visualizer = h c6;
        launcher = h activeBorder;
      };
    };
}
