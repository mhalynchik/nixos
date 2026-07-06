{ config, lib, pkgs, vars, ... }:

let
  vpnBasePath = "${vars.homeDirectory}/vpn";
  mkOpenVpnServer = name: configFile: {
    config = ''
      config ${configFile}
      auth-user-pass /etc/openvpn/credentials
    '';
    autoStart = false;
  };
  defaultOpenVpnConfigs = [
    { name = "vpn-lt"; file = "${vpnBasePath}/rsv.LT.ovpn"; }
    { name = "vpn-lv"; file = "${vpnBasePath}/rsv.LV.ovpn"; }
    { name = "vpn-po"; file = "${vpnBasePath}/rsv.PO.ovpn"; }
    { name = "vpn-fin"; file = "${vpnBasePath}/rsv.FIN.ovpn"; }
    { name = "vpn-am"; file = "${vpnBasePath}/rsv.AM.ovpn"; }
    { name = "vpn-bu"; file = "${vpnBasePath}/rsv.BU.ovpn"; }
    { name = "vpn-ge"; file = "${vpnBasePath}/rsv.GE.ovpn"; }
  ];
  openvpnEntries =
    if vars.vpn.openvpnConfigs != [ ]
    then vars.vpn.openvpnConfigs
    else defaultOpenVpnConfigs;
in
{
  services.openvpn.servers = lib.listToAttrs (
    map (entry: {
      name = entry.name;
      value = mkOpenVpnServer entry.name entry.file;
    }) openvpnEntries
  );

  environment.systemPackages = with pkgs; [ openvpn ];
}
