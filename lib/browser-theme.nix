{ pkgs, name, package, homeConfig }:
let
  # Store paths belong to this generation even before linkGeneration runs.
  theme = pkgs.linkFarm "${name}-theme" (map (file: {
    name = file;
    path = homeConfig.home.file.".config/${name}-theme/${file}".source;
  }) [ "userChrome.css" "userContent.css" "user.js" ]);
in
pkgs.writeShellScriptBin "apply-${name}-theme" ''
  exec ${pkgs.python3}/bin/python3 ${./apply-browser-theme.py} \
    "$HOME/.${name}" ${theme} ${package}/bin/${name}
''
