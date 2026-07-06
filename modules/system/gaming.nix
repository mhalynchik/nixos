{ config, lib, pkgs, vars, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 10;
        softrealtime = "auto";
        reaper_freq = 5;
        desiredgov = "performance";
        igpu_desiredgov = "performance";
        igpu_power_threshold = 0.3;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = vars.gamemodeGpuDevice;
        nv_powermizer_mode = 1;
      };
    };
  };
}
