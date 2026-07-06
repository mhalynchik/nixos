{ config, pkgs, lib, vars, ... }:

let
  defaultWireguardConfigs = [
    { name = "latvia"; configFile = "/etc/wireguard/latvia.conf"; autostart = false; }
  ];
  wireguardEntries =
    if vars.vpn.wireguardConfigs != [ ]
    then vars.vpn.wireguardConfigs
    else defaultWireguardConfigs;
in
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
    amneziawg-tools
  ];

  boot.extraModulePackages = [ config.boot.kernelPackages.amneziawg ];

  networking.wg-quick.interfaces = lib.listToAttrs (
    map (entry: {
      name = entry.name;
      value = {
        inherit (entry) configFile autostart;
      };
    }) wireguardEntries
  );

  networking.firewall.checkReversePath = "loose";
}
