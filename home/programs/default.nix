{ vars, lib, ... }:

{
  imports =
    [
      ./kitty
      ./zsh
      ./bash
      ./hypr
      ./rofi
      ./wlogout
      ./swayosd
      ./clipboard
    ]
    ++ lib.optionals (vars.programs.eventHorizon or false) [ ./event-horizon ]
    ++ lib.optionals (!(vars.programs.eventHorizon or false)) [ ./waybar ./swaync ]
    ++ lib.optionals (vars.programs.ags && !(vars.programs.eventHorizon or false)) [ ./ags ]
    ++ lib.optionals (vars.browser == "floorp") [ ./floorp ]
    ++ lib.optionals (vars.browser == "librewolf") [ ./librewolf ]
    ++ lib.optionals vars.programs.vscode [ ./vscode ]
    ++ lib.optionals vars.programs.zed [ ./zed ]
    ++ lib.optionals vars.programs.lunarvim [ ./lunarvim ]
    ++ lib.optionals vars.programs.cursor [ ./cursor ]
    ++ lib.optionals vars.programs.spotify [ ./spotify ]
    ++ lib.optionals vars.programs.airi [ ./airi ]
    ++ lib.optionals vars.programs.chatgpt [ ./chatgpt ]
    ++ lib.optionals vars.programs.telegram [ ./telegram ]
    ++ lib.optionals vars.programs.planify [ ./planify ]
    ++ lib.optionals (vars.features.gaming && vars.programs.steam) [ ./steam ];
}
