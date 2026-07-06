{ config, pkgs, ... }:

{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      extraConfig = {
        "50-bluez-config" = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.codecs" = [ "aac" "sbc" "sbc_xq" ];
            "bluez5.roles" = [ "a2dp_sink" "a2dp_source" "bap_sink" "bap_source" ];
          };
          "monitor.bluez.rules" = [
            {
              matches = [{ "device.name" = "~bluez_card.*"; }];
              actions.update-props = {
                "bluez5.auto-connect" = [ "a2dp_sink" "a2dp_source" ];
                "bluez5.codec-order" = [ "aac" "sbc" "sbc_xq" ];
                "bluez5.autoswitch-profile" = false;
              };
            }
          ];
        };
      };
    };
  };
}
