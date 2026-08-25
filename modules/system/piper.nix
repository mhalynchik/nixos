{ lib, pkgs, vars, ... }:

# Piper TTS for AIRI. :8179 = OpenAI speech. :4315 = Player2 default URL
# (AIRI Player2 card does not persist a custom baseUrl).
let
  python = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.pydantic
  ]);

  irinaOnnx = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx";
    sha256 = "1amar8mf44vqn675a0fypzq7b52vdrg68p3hwfxh18rxs8985wwg";
  };

  irinaConfig = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json";
    sha256 = "1mx9k27d018jskazwc1g4yyypby1901y9csrp69rxdg272xjiv62";
  };

  piper = vars.piper;
  player2Port = 4315;

  piperUnit = port: {
    description = "Local Piper Russian TTS on :${toString port}";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.ffmpeg ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${python}/bin/python ${./piper-server.py}";
      Restart = "on-failure";
      RestartSec = "5";
      DynamicUser = true;
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      Environment = [
        "PYTHONUNBUFFERED=1"
        "PIPER_BIN=${pkgs.piper-tts}/bin/piper"
        "PIPER_VOICE=${irinaOnnx}"
        "PIPER_CONFIG=${irinaConfig}"
        "PIPER_HOST=${piper.host}"
        "PIPER_PORT=${toString port}"
        "FFMPEG_BIN=${pkgs.ffmpeg}/bin/ffmpeg"
      ];
    };
  };
in
{
  systemd.services.piper = piperUnit piper.port;
  systemd.services.piper-player2 = lib.mkIf (piper.port != player2Port) (piperUnit player2Port);
}
