{ vars, lib, ... }:

{
  imports =
    [
      ./kitty
      ./zsh
      ./bash
      ./hypr
      ./rofi
      ./waybar
      ./wlogout
      ./swaync
    ]
    ++ lib.optionals vars.programs.ags [ ./ags ]
    ++ lib.optionals (vars.browser == "floorp") [ ./floorp ]
    ++ lib.optionals vars.programs.vscode [ ./vscode ]
    ++ lib.optionals vars.programs.zed [ ./zed ]
    ++ lib.optionals vars.programs.lunarvim [ ./lunarvim ]
    ++ lib.optionals vars.programs.cursor [ ./cursor ]
    ++ lib.optionals vars.programs.spotify [ ./spotify ]
    ++ lib.optionals vars.programs.telegram [ ./telegram ]
    ++ lib.optionals vars.programs.planify [ ./planify ]
    ++ lib.optionals (vars.features.gaming && vars.programs.steam) [ ./steam ];
}
