{ vars, pkgs, ... }:

# 25.05 services.ollama: DynamicUser + ProtectHome. Models live in
# /var/lib/ollama/models, not ~/.ollama. Pull with
# OLLAMA_HOST=http://127.0.0.1:11434 after the unit is up.
{
  services.ollama = {
    enable = true;
    acceleration = if vars.features.nvidia then "cuda" else false;
    host = vars.ollama.host;
    port = vars.ollama.port;
    loadModels = vars.ollama.loadModels;
  };

  environment.systemPackages = [ pkgs.ollama ];
}
