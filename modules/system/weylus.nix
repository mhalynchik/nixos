{ pkgs, vars, ... }:

{
  programs.weylus = {
    enable = true;
    openFirewall = true;
    users = [ vars.username ];
  };

  # USB: `adb reverse` без общей Wi-Fi сети (см. docs/weylus.md).
  environment.systemPackages = [ pkgs.android-tools ];
}
