{ lib, pkgs, pkgs-unstable, vars, inputs, ... }:

let
  package = pkgs.callPackage ./package.nix {
    quickshell = pkgs-unstable.quickshell;
  };
  gallery = import ../../themes/gallery { inherit lib inputs; };
  wallpaperConfig = pkgs.writeText "event-horizon-wallpapers.json" (builtins.toJSON {
    static = [ "${vars.homeDirectory}/${vars.staticWallpapersDir}" ]
      ++ lib.optional (gallery.wallpaperDirFor vars.theme != "") (gallery.wallpaperDirFor vars.theme);
    animated = [ "${vars.homeDirectory}/${vars.animatedWallpapersDir}" ];
  });
  wallpaper = "${vars.homeDirectory}/${vars.staticWallpapersDir}/event-horizon.png";
in
{
  home-manager.users.${vars.username} = { lib, ... }: {
    home.packages = [ package ];
    home.file.".local/share/fonts/event-horizon".source = ./ui/fonts;

    systemd.user.services.event-horizon = {
      Unit = {
        Description = "Event Horizon desktop shell";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "hyprland-session.target" ];
        Conflicts = [ "ags.service" "swaync.service" ];
      };
      Service = {
        ExecStart = "${package}/bin/event-horizon";
        ExecStopPost = "${package}/bin/event-horizon-wallpaper-restore";
        Environment = [ "EVENT_HORIZON_WALLPAPER_CONFIG=${wallpaperConfig}" ];
        Restart = "on-failure";
        RestartSec = 3;
        KillMode = "control-group";
        TimeoutStopSec = 10;
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    programs.waybar = {
      enable = true;
      systemd.enable = true;
      systemd.target = "hyprland-session.target";
      style = builtins.readFile ./integration/waybar.css;
      settings = [{
        layer = "top";
        position = "top";
        height = 36;
        margin-top = 4;
        margin-left = 6;
        margin-right = 6;
        margin-bottom = 0;
        modules-left = [ "group/left" ];
        modules-center = [];
        modules-right = [];
        "group/left" = {
          orientation = "inherit";
          modules = [ "custom/launcher" "hyprland/workspaces" "hyprland/language" "tray" ];
        };
        "custom/launcher" = {
          format = "";
          on-click = "${package}/bin/event-horizon ipc call design open launcher";
          on-click-right = "rofi -show run";
          tooltip-format = "Приложения";
        };
        "hyprland/workspaces" = {
          all-outputs = false;
          format = "{name}";
          on-click = "activate";
          sort-by-number = true;
          persistent-workspaces."*" = [ 1 2 3 4 ];
        };
        "hyprland/language" = {
          format = "{}";
          format-en = "EN";
          format-ru = "RU";
          on-click = "hyprctl switchxkblayout all next";
        };
        tray = { icon-size = 16; spacing = 8; };
      }];
    };

    wayland.windowManager.hyprland.settings.layerrule = [
      "noanim,emerald-overlay"
      "noanim,emerald-desktop"
      "blur,emerald-overlay"
      "ignorealpha 0.05,emerald-overlay"
    ];

    # Adopt the accepted wallpaper once; subsequent rebuilds preserve picker choices.
    home.activation.eventHorizonWallpaper = lib.hm.dag.entryAfter [ "linkGeneration" "initWallpaperSymlinks" ] ''
      state="${vars.homeDirectory}/.local/state"
      run mkdir -p "$state/event-horizon"
      run ${pkgs.coreutils}/bin/install -Dm644 ${./ui/sky.png} ${lib.escapeShellArg wallpaper}
      if [ ! -e "$state/event-horizon/wallpaper-adopted" ]; then
        if [ -e "$state/current-wallpaper" ]; then
          run ${pkgs.writeShellScript "remember-previous-wallpaper" ''
            readlink -f "$1/current-wallpaper" > "$1/event-horizon/previous-wallpaper"
          ''} "$state"
        fi
        run ln -sfn ${lib.escapeShellArg wallpaper} "$state/current-wallpaper"
        run ln -sfn ${lib.escapeShellArg wallpaper} "$state/current-lock-wallpaper"
        run touch "$state/event-horizon/wallpaper-adopted"
      fi
    '';
  };
}
