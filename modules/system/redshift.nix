{ config, pkgs, vars, ... }:

{
  environment.systemPackages = with pkgs; [
    redshift
    wlsunset
    mpvpaper
  ];

  services.redshift = {
    enable = true;
    temperature = {
      day = 5500;
      night = 3700;
    };
  };

  location = {
    provider = "manual";
    latitude = vars.location.latitude;
    longitude = vars.location.longitude;
  };
}
