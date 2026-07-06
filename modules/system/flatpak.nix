{ config, lib, pkgs, vars, ... }:

{
  services.flatpak.enable = true;
  system.activationScripts.flatpakApps = lib.mkIf vars.features.flatpak ''
    export PATH="${pkgs.flatpak}/bin:$PATH"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --noninteractive --or-update flathub ru.linux_gaming.PortProton || true
    flatpak override ru.linux_gaming.PortProton --filesystem=home --no-talk-name=org.freedesktop.portal.FileChooser 2>/dev/null || true
  '';
}
