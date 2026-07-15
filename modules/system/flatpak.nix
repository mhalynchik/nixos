{ config, lib, pkgs, vars, colors, ... }:

let
  # Flatpak apps that should follow the desktop GTK/icon theme. The Gallery
  # override is applied per app, never globally, and is reverted for these same
  # apps when switching back to a builtin theme.
  themedFlatpakApps = [ "ru.linux_gaming.PortProton" ];

  # Grant read-only access to the user theme/icon data dirs (populated with
  # symlinks to the Gallery store derivations in home/themes/default.nix) and
  # select the Gallery GTK theme inside the sandbox.
  _galleryOverride = app: ''
    flatpak override ${app} --filesystem=xdg-data/themes:ro --filesystem=xdg-data/icons:ro --env=GTK_THEME=${colors.gtkThemeEnv} 2>/dev/null || true
  '';

  # Revert only the keys we manage so a Gallery -> builtin rebuild drops them.
  _resetOverride = app: ''
    flatpak override ${app} --nofilesystem=xdg-data/themes --nofilesystem=xdg-data/icons --unset-env=GTK_THEME 2>/dev/null || true
  '';

  _themeScript =
    if colors.galleryActive
    then lib.concatMapStrings _galleryOverride themedFlatpakApps
    else lib.concatMapStrings _resetOverride themedFlatpakApps;
in
{
  services.flatpak.enable = true;
  system.activationScripts.flatpakApps = lib.mkIf vars.features.flatpak (''
    export PATH="${pkgs.flatpak}/bin:$PATH"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --noninteractive --or-update flathub ru.linux_gaming.PortProton || true
    flatpak override ru.linux_gaming.PortProton --filesystem=home --no-talk-name=org.freedesktop.portal.FileChooser 2>/dev/null || true
  '' + _themeScript);
}
