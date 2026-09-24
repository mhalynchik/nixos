# Home Manager fragment. Override the existing watchers only for Event Horizon;
# other desktop themes keep their original cliphist services and picker.
{ pkgs, lib, package }:
let
  watcher = type: pkgs.writeShellApplication {
    name = "event-horizon-clipboard-${type}";
    runtimeInputs = [ pkgs.wl-clipboard pkgs.python3 pkgs.ffmpeg ];
    text = ''
      umask 077
      exec wl-paste --type ${type} --watch python3 ${package}/share/event-horizon/runtime/desktop_tools.py --watch ${type}
    '';
  };
in {
  systemd.user.services.cliphist-watcher.Service.ExecStart = lib.mkForce "${watcher "text"}/bin/event-horizon-clipboard-text";
  systemd.user.services.cliphist-watcher-image.Service.ExecStart = lib.mkForce "${watcher "image"}/bin/event-horizon-clipboard-image";
}
