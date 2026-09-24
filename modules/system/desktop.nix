{ config, lib, pkgs, vars, colors, ... }:
let
  desktopSession = pkgs.writeShellScript "start-hyprland" ''
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(${pkgs.coreutils}/bin/id -u)/bus"
    # Do not leave idle daemons attached to the previous compositor/session.
    trap '${pkgs.systemd}/bin/systemctl --user stop hyprland-session.target graphical-session.target' EXIT
    /run/current-system/sw/bin/Hyprland
    exit $?
  '';
in
{
  services.greetd.enable = true;
  services.greetd.settings = {
    # Autologin is a real user session, never the greeter's desktop.
    initial_session = { command = "${desktopSession}"; user = vars.username; };
    default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --greeting 'Event Horizon' --theme 'border=green;text=white;prompt=green;action=cyan;button=green' --cmd ${desktopSession}";
      user = "greeter";
    };
  };

  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland,x11";
    TRACKER_DB_HOME = "/dev/null";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
  } // lib.optionalAttrs colors.galleryActive {
    # Gallery GTK theme name for apps that read GTK_THEME from the environment.
    # Builtin themes rely on Home Manager gtk.theme (Stylix), not this override.
    GTK_THEME = colors.gtkThemeEnv;
  };

  services.gnome.at-spi2-core.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    gsettings-desktop-schemas
    gtk3
    gnome-settings-daemon
    adwaita-icon-theme
    pulseaudio
    remmina
    freerdp
    gnome-connections
    mesa
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    git
    curl
    wget
    jq
    ripgrep
  ];

  programs.bash.completion.enable = true;

  environment.pathsToLink = [ "/share/gsettings-schemas" ];
  environment.extraInit = ''
    export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS"
  '';
}
