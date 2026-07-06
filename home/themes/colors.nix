# Centralized color scheme and transparency settings
# Theme selection is based on vars.theme
# This file provides consistent theming across all applications

let
  # Import theme palettes
  palettes = {
    catppuccin = import ./palettes/catppuccin.nix;
    crimson = import ./palettes/crimson.nix;
  };

  # Import vars using relative path (works from any location)
  # colors.nix is at: <config>/home/themes/colors.nix
  # vars.nix is at:   <config>/vars.nix
  vars = import ../../vars.nix;

  # Select active palette based on vars.theme
  activePalette = palettes.${vars.theme} or palettes.catppuccin;

  # Helper: convert hex char to int
  hexCharToInt = c:
    if c == "0" then 0 else if c == "1" then 1 else if c == "2" then 2
    else if c == "3" then 3 else if c == "4" then 4 else if c == "5" then 5
    else if c == "6" then 6 else if c == "7" then 7 else if c == "8" then 8
    else if c == "9" then 9 else if c == "a" || c == "A" then 10
    else if c == "b" || c == "B" then 11 else if c == "c" || c == "C" then 12
    else if c == "d" || c == "D" then 13 else if c == "e" || c == "E" then 14
    else if c == "f" || c == "F" then 15 else 0;

  # Helper: parse 2-char hex to int (e.g., "ff" -> 255)
  hexPairToInt = s:
    let
      c1 = builtins.substring 0 1 s;
      c2 = builtins.substring 1 1 s;
    in (hexCharToInt c1) * 16 + (hexCharToInt c2);
in
{
  # Re-export the active palette
  inherit (activePalette) name displayName base16 colors hyprland waybar;

  # Transparency settings (shared across themes)
  transparency = {
    normal = 0.6;        # 60% opacity for apps that support it
    high = 0.85;         # 85% for elements needing more visibility
    low = 0.4;           # 40% for background elements
    solid = 1.0;         # Fully opaque
  };

  # Convert hex color to rgba() for GTK CSS
  # Usage: toRgba "#1e1e2e" 0.65  ->  "rgba(30, 30, 46, 0.65)"
  toRgba = color: alpha:
    let
      # Remove # prefix if present
      hex = if builtins.substring 0 1 color == "#"
            then builtins.substring 1 6 color
            else builtins.substring 0 6 color;
      r = hexPairToInt (builtins.substring 0 2 hex);
      g = hexPairToInt (builtins.substring 2 2 hex);
      b = hexPairToInt (builtins.substring 4 2 hex);
    in "rgba(${toString r}, ${toString g}, ${toString b}, ${toString alpha})";

  # Convert opacity to hex (e.g., 0.6 -> "99")
  opacityToHex = opacity: let
    hex = builtins.floor (opacity * 255);
    hexChars = ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"];
    toHex = n: if n < 16 then builtins.elemAt hexChars n else
      (toHex (n / 16)) + (builtins.elemAt hexChars (n - (n / 16) * 16));
  in if hex < 16 then "0${toHex hex}" else toHex hex;

  # Colors with transparency (for CSS rgba) - DEPRECATED, use toRgba instead
  withAlpha = color: alpha: "${color}${
    let
      hex = builtins.floor (alpha * 255);
      hexChars = ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"];
      high = hex / 16;
      low = hex - (high * 16);
    in
      (builtins.elemAt hexChars high) + (builtins.elemAt hexChars low)
  }";

  # GTK/Qt theme names
  gtkTheme = "Adwaita-dark";
  iconTheme = "Papirus-Dark";
  cursorTheme = "Bibata-Modern-Classic";

  # Font settings (shared)
  fonts = {
    monospace = "JetBrainsMono Nerd Font";
    sans = "Inter";
    serif = "Noto Serif";
    size = {
      small = 10;
      normal = 12;
      large = 14;
    };
  };
}
