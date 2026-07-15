{ config, pkgs, vars, lib, ... }:

let
  wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
  wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
  cliphistBin = "${pkgs.cliphist}/bin/cliphist";

  clipboardPicker = pkgs.writeShellApplication {
    name = "clipboard-picker";
    runtimeInputs = with pkgs; [ rofi-wayland cliphist wl-clipboard coreutils ];
    text = ''
      set -euo pipefail
      entry=$(${cliphistBin} list | rofi -dmenu -i -p "Clipboard") || true
      if [ -z "$entry" ]; then exit 0; fi
      ${cliphistBin} decode <<< "$entry" | ${wlCopy}
    '';
  };

  cliphistWatcherText = pkgs.writeShellApplication {
    name = "cliphist-watcher";
    runtimeInputs = with pkgs; [ wl-clipboard cliphist coreutils ];
    text = ''
      exec ${wlPaste} --type text --watch ${cliphistBin} store
    '';
  };

  cliphistWatcherImage = pkgs.writeShellApplication {
    name = "cliphist-watcher-image";
    runtimeInputs = with pkgs; [ wl-clipboard cliphist coreutils ];
    text = ''
      exec ${wlPaste} --type image --watch ${cliphistBin} store
    '';
  };
in
{
  home-manager.users.${vars.username} = {
    home.packages = [ clipboardPicker ];

    systemd.user.services.cliphist-watcher = {
      Unit = {
        Description = "Cliphist clipboard watcher (text)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        # Skip on non-Wayland sessions (no wl-paste socket to watch).
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${cliphistWatcherText}/bin/cliphist-watcher";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.cliphist-watcher-image = {
      Unit = {
        Description = "Cliphist clipboard watcher (image)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        # Skip on non-Wayland sessions (no wl-paste socket to watch).
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${cliphistWatcherImage}/bin/cliphist-watcher-image";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
