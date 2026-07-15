# HyDE Gallery domain: registry of curated, declaratively pinned Gallery themes.
#
# Each entry references a flake input pinned by commit (see flake.nix). Nothing
# is downloaded at activation time and nothing is written to ~/.config/hyde.
# The registry exposes:
#   - palettes: adapted color interfaces (pure, no pkgs) for colors.nix
#   - registry: raw metadata + source paths for asset unpacking (assets.nix)
{ lib, inputs }:

let
  adapter = import ./adapter.nix { inherit lib; };

  registry = {
    "catppuccin-mocha" = {
      source = inputs.hyde-theme-catppuccin-mocha;
      themeSubdir = "Configs/.config/hyde/themes/Catppuccin Mocha";
      displayName = "Catppuccin Mocha (HyDE Gallery)";
      wallpapersSubdir = "wallpapers";
      gtk = {
        archive = "Source/Gtk_CatppuccinMocha.tar.gz";
        themeName = "Catppuccin-Mocha";
      };
      icon = {
        archive = "Source/Icon_TelaDracula.tar.gz";
        themeName = "Tela-circle-dracula";
      };
    };
  };
  _def = theme: registry.${theme} or null;
in
{
  inherit registry;

  palettes = lib.mapAttrs
    (name: def: adapter.palette {
      inherit name;
      inherit (def) displayName;
      themePath = "${def.source}/${def.themeSubdir}";
    })
    registry;

  # True when vars.theme selects a curated Gallery adapter (not a builtin).
  isGallery = theme: registry ? ${theme};

  # Read-only store dir with curated wallpapers for the wallpaper domain bridge.
  # Pure (no pkgs); returns "" for builtin themes.
  wallpaperDirFor = theme:
    let def = _def theme;
    in if def == null then "" else "${def.source}/${def.themeSubdir}/${def.wallpapersSubdir}";

  # GTK theme name (folder) for the active Gallery theme; "" for builtin.
  gtkThemeNameFor = theme:
    let def = _def theme;
    in if def == null then "" else def.gtk.themeName;

  # Icon theme name (folder) for the active Gallery theme; "" for builtin.
  iconThemeNameFor = theme:
    let def = _def theme;
    in if def == null then "" else def.icon.themeName;

  # Unpacked GTK/icon asset derivations for the active Gallery theme (needs
  # pkgs). Returns null for builtin themes.
  assetsFor = { pkgs, theme }:
    let def = _def theme;
    in if def == null then null
       else import ./assets.nix { inherit pkgs def; source = def.source; };
}
