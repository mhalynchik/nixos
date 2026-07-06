{ config, lib, pkgs, vars, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = vars.features.sshPasswordAuth;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
