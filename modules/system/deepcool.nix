{ config, lib, pkgs, vars, ... }:

{
  services.udev.extraRules = lib.mkIf vars.features.deepcool ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", MODE="0666"
    SUBSYSTEM=="usb", ATTR{idVendor}=="3633", MODE="0666"
  '';

  systemd.services.deepcool-mystique = lib.mkIf (vars.features.deepcool && vars.deepcoolScript != null) {
    description = "DeepCool MYSTIQUE 360 LCD Display Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "systemd-udevd.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = "${vars.deepcoolScript} --mode cpu --interval 1000";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
}
