{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /var/lib/bluetooth 700 root root - -"
  ];
  systemd.targets."bluetooth".after = [ "systemd-tmpfiles-setup.service" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="8771", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"
  '';

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        DiscoverableTimeout = 0;
        PairableTimeout = 0;
        FastConnectable = true;
        MultiProfile = "off";
      };
      Policy.AutoEnable = true;
    };
  };

  services.blueman.enable = true;
}
