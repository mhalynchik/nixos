{ pkgs, vars, ... }:

# OpenAI-compatible /v1/audio/transcriptions for AIRI.
# 25.05 python3Packages.ctranslate2 is CPU-only; device=cuda falls back to cpu.
let
  python = pkgs.python3.withPackages (ps: [
    ps.faster-whisper
    ps.fastapi
    ps.uvicorn
    ps.python-multipart
  ]);

  whisper = vars.whisper;
in
{
  systemd.services.whisper = {
    description = "Local OpenAI-compatible Whisper transcription";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${python}/bin/python ${./whisper-server.py}";
      Restart = "on-failure";
      RestartSec = "10";
      TimeoutStartSec = "0";
      DynamicUser = true;
      StateDirectory = "whisper";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      Environment = [
        "PYTHONUNBUFFERED=1"
        "HF_HOME=/var/lib/whisper/hf"
        "WHISPER_DOWNLOAD_ROOT=/var/lib/whisper/models"
        "WHISPER_HOST=${whisper.host}"
        "WHISPER_PORT=${toString whisper.port}"
        "WHISPER_MODEL=${whisper.model}"
        "WHISPER_LANGUAGE=${whisper.language}"
        "WHISPER_DEVICE=${whisper.device}"
      ];
    };
  };
}
