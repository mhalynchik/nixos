{ lib, vars, ... }:

let
  nvidia = vars.features.nvidia;

  quality = {
    sw_preset = "fast";
    sw_tune = "animation";
    fec_percentage = "10";
    max_bitrate = "50000";
    min_threads = "8";
  };
in
{
  # Только зеркало. Headless TABLET забирал workspace 2/10 на невидимый
  # монитор. KMS не видит Hyprland headless — второй экран на этом стеке нет.
  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;
    settings = {
      capture = "kms";
      stream_audio = "disabled";
    } // quality // lib.optionalAttrs nvidia {
      encoder = "software";
      adapter_name = "/dev/dri/renderD129";
    };
    applications.apps = [
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
    ];
  };
}
