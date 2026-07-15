# Structured keybind source (SSOT) for Hyprland binds and cheatsheet generation.
{ lib, vars }:

let
  modifierRank = mod:
    if mod == "SUPER" then 0
    else if mod == "SHIFT" then 1
    else if mod == "CTRL" then 2
    else if mod == "ALT" then 3
    else if mod == "HYPER" then 4
    else if mod == "META" then 5
    else 6;

  normalizeMod = mod:
    if mod == "$mainMod" || mod == "SUPER" then "SUPER" else mod;

  canonicalMods = mods:
    lib.sort (a: b: modifierRank a < modifierRank b) (map normalizeMod mods);

  modsToHypr = mods:
    let
      canon = canonicalMods mods;
    in
      if canon == [ "SUPER" ] then "$mainMod"
      else lib.concatStringsSep " " canon;

  directiveName = entry:
    let
      phase = entry.phase or "press";
      repeat = entry.repeat or false;
      locked = entry.locked or false;
      mouse = entry.mouse or false;
    in
      if mouse then "bindm"
      else if phase == "release" then
        if locked then "bindrl" else "bindr"
      else if repeat then
        if locked then "bindel" else "binde"
      else if locked then "bindl"
      else "bind";

  activationGroup = entry:
    let
      phase = entry.phase or "press";
      mouse = entry.mouse or false;
    in
      if mouse then "mouse"
      else if phase == "release" then "up"
      else "down";

  bindEntry =
    { modifiers ? [ ], key, phase ? "press", repeat ? false, locked ? false, mouse ? false, chain ? false, dispatcher, argument ? "", description, category }:
    {
      inherit modifiers key phase repeat locked mouse chain dispatcher argument description category;
    };

  bindDefinitions = [
    { modifiers = [ "SUPER" ]; key = "Return"; dispatcher = "exec"; argument = "$terminal"; description = "Terminal"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "C"; dispatcher = "exec"; argument = "$terminal"; description = "Terminal"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "E"; dispatcher = "exec"; argument = "$fileManager"; description = "File manager"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "L"; dispatcher = "exec"; argument = "$browser"; description = "Browser"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "R"; dispatcher = "exec"; argument = "$menu"; description = "App menu"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "W"; dispatcher = "exec"; argument = "rofi -show drun -show-icons"; description = "App launcher"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "G"; dispatcher = "exec"; argument = "rofi -modi games -show games -show-icons -theme games"; description = "Games menu"; category = "Applications"; }
    { modifiers = [ "SUPER" ]; key = "A"; dispatcher = "exec"; argument = "nwg-drawer"; description = "App drawer"; category = "Applications"; }

    { modifiers = [ "SUPER" ]; key = "Q"; dispatcher = "killactive"; description = "Close window"; category = "Windows"; }
    { modifiers = [ "SUPER" ]; key = "V"; dispatcher = "togglefloating"; description = "Toggle floating"; category = "Windows"; }
    { modifiers = [ "SUPER" ]; key = "F"; dispatcher = "fullscreen"; argument = "1"; description = "Fullscreen"; category = "Windows"; }
    { modifiers = [ "SUPER" ]; key = "P"; dispatcher = "pseudo"; description = "Pseudo tile"; category = "Windows"; }
    { modifiers = [ "SUPER" ]; key = "J"; dispatcher = "togglesplit"; description = "Toggle split"; category = "Windows"; }
    { modifiers = [ "SUPER" ]; key = "M"; dispatcher = "exit"; description = "Exit Hyprland"; category = "System"; }

    { modifiers = [ "SUPER" ]; key = "F12"; dispatcher = "exec"; argument = ''grim -g "$(slurp)" - | wl-copy''; description = "Screenshot to clipboard"; category = "Screenshots"; }
    { modifiers = [ ]; key = "Print"; dispatcher = "exec"; argument = ''grim -g "$(slurp)" - | wl-copy''; description = "Screenshot to clipboard"; category = "Screenshots"; }
    { modifiers = [ "SHIFT" ]; key = "Print"; dispatcher = "exec"; argument = ''grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png''; description = "Screenshot to file"; category = "Screenshots"; }
    { modifiers = [ "SUPER" "CTRL" ]; key = "S"; dispatcher = "exec"; argument = ''grim -g "$(slurp)" - | swappy -f -''; description = "Screenshot editor"; category = "Screenshots"; }

    { modifiers = [ "SUPER" ]; key = "B"; dispatcher = "exec"; argument = "waybar-toggle"; description = "Toggle Waybar"; category = "Waybar"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "B"; dispatcher = "exec"; argument = "waybar-restart"; description = "Restart Waybar"; category = "Waybar"; }

    { modifiers = [ "SUPER" "SHIFT" ]; key = "W"; dispatcher = "exec"; argument = "wallpaper-picker"; description = "Wallpaper picker"; category = "Wallpaper"; }
    { modifiers = [ "SUPER" "ALT" ]; key = "W"; dispatcher = "exec"; argument = "wallpaper-animated"; description = "Animated wallpaper"; category = "Wallpaper"; }

    { modifiers = [ "SUPER" "SHIFT" ]; key = "C"; dispatcher = "exec"; argument = "hyprpicker -a"; description = "Color picker"; category = "Tools"; }
    { modifiers = [ "SUPER" "ALT" ]; key = "equal"; dispatcher = "exec"; argument = "opacity-increase"; description = "Increase opacity"; category = "Windows"; }
    { modifiers = [ "SUPER" "ALT" ]; key = "minus"; dispatcher = "exec"; argument = "opacity-decrease"; description = "Decrease opacity"; category = "Windows"; }
    { modifiers = [ "SUPER" "ALT" ]; key = "0"; dispatcher = "exec"; argument = "opacity-reset"; description = "Reset opacity"; category = "Windows"; }

    { modifiers = [ "SUPER" "SHIFT" ]; key = "L"; dispatcher = "exec"; argument = "hyprlock"; description = "Lock screen"; category = "System"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "V"; dispatcher = "exec"; argument = "clipboard-picker"; description = "Clipboard history"; category = "Tools"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "K"; dispatcher = "exec"; argument = "cheatsheet"; description = "Keybind cheatsheet"; category = "System"; }

    { modifiers = [ "SUPER" ]; key = "period"; dispatcher = "exec"; argument = "emoji-picker"; description = "Emoji picker"; category = "Tools"; }
    { modifiers = [ "SUPER" ]; key = "comma"; dispatcher = "exec"; argument = "glyph-picker"; description = "Glyph picker"; category = "Tools"; }
    { modifiers = [ "SUPER" "ALT" ]; key = "S"; dispatcher = "exec"; argument = "rofi-websearch"; description = "Web search"; category = "Tools"; }
    { modifiers = [ "SUPER" "ALT" ]; key = "C"; dispatcher = "exec"; argument = "rofi-calc"; description = "Calculator"; category = "Tools"; }

    { modifiers = [ "SUPER" ]; key = "N"; dispatcher = "exec"; argument = "swaync-client -t -sw"; description = "Toggle notifications"; category = "Notifications"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "N"; dispatcher = "exec"; argument = "swaync-client -d -sw"; description = "Clear notifications"; category = "Notifications"; }

    { modifiers = [ "SUPER" ]; key = "left"; dispatcher = "movefocus"; argument = "l"; description = "Focus left"; category = "Focus"; }
    { modifiers = [ "SUPER" ]; key = "right"; dispatcher = "movefocus"; argument = "r"; description = "Focus right"; category = "Focus"; }
    { modifiers = [ "SUPER" ]; key = "up"; dispatcher = "movefocus"; argument = "u"; description = "Focus up"; category = "Focus"; }
    { modifiers = [ "SUPER" ]; key = "down"; dispatcher = "movefocus"; argument = "d"; description = "Focus down"; category = "Focus"; }

    # Explicitly chained: two plain binds on SUPER+Tab fire in sequence (allowed).
    { modifiers = [ "SUPER" ]; key = "Tab"; chain = true; dispatcher = "cyclenext"; description = "Cycle windows"; category = "Windows"; }
    { modifiers = [ "SUPER" ]; key = "Tab"; chain = true; dispatcher = "bringactivetotop"; description = "Bring active to top"; category = "Windows"; }

    { modifiers = [ "SUPER" ]; key = "1"; dispatcher = "workspace"; argument = "1"; description = "Workspace 1"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "2"; dispatcher = "workspace"; argument = "2"; description = "Workspace 2"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "3"; dispatcher = "workspace"; argument = "3"; description = "Workspace 3"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "4"; dispatcher = "workspace"; argument = "4"; description = "Workspace 4"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "5"; dispatcher = "workspace"; argument = "5"; description = "Workspace 5"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "6"; dispatcher = "workspace"; argument = "6"; description = "Workspace 6"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "7"; dispatcher = "workspace"; argument = "7"; description = "Workspace 7"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "8"; dispatcher = "workspace"; argument = "8"; description = "Workspace 8"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "9"; dispatcher = "workspace"; argument = "9"; description = "Workspace 9"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "0"; dispatcher = "workspace"; argument = "10"; description = "Workspace 10"; category = "Workspaces"; }

    { modifiers = [ "SUPER" "SHIFT" ]; key = "1"; dispatcher = "movetoworkspace"; argument = "1"; description = "Move to workspace 1"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "2"; dispatcher = "movetoworkspace"; argument = "2"; description = "Move to workspace 2"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "3"; dispatcher = "movetoworkspace"; argument = "3"; description = "Move to workspace 3"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "4"; dispatcher = "movetoworkspace"; argument = "4"; description = "Move to workspace 4"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "5"; dispatcher = "movetoworkspace"; argument = "5"; description = "Move to workspace 5"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "6"; dispatcher = "movetoworkspace"; argument = "6"; description = "Move to workspace 6"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "7"; dispatcher = "movetoworkspace"; argument = "7"; description = "Move to workspace 7"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "8"; dispatcher = "movetoworkspace"; argument = "8"; description = "Move to workspace 8"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "9"; dispatcher = "movetoworkspace"; argument = "9"; description = "Move to workspace 9"; category = "Workspaces"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "0"; dispatcher = "movetoworkspace"; argument = "10"; description = "Move to workspace 10"; category = "Workspaces"; }

    { modifiers = [ "SUPER" ]; key = "mouse_down"; dispatcher = "workspace"; argument = "e+1"; description = "Next workspace"; category = "Workspaces"; }
    { modifiers = [ "SUPER" ]; key = "mouse_up"; dispatcher = "workspace"; argument = "e-1"; description = "Previous workspace"; category = "Workspaces"; }

    { modifiers = [ "SUPER" ]; key = "S"; dispatcher = "togglespecialworkspace"; argument = "magic"; description = "Toggle scratchpad"; category = "Scratchpad"; }
    { modifiers = [ "SUPER" "SHIFT" ]; key = "S"; dispatcher = "exec"; argument = "scratchpad-toggle"; description = "Scratchpad round-trip"; category = "Scratchpad"; }

    { modifiers = [ "SUPER" "CTRL" ]; key = "left"; dispatcher = "focusmonitor"; argument = "l"; description = "Focus monitor left"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" ]; key = "right"; dispatcher = "focusmonitor"; argument = "r"; description = "Focus monitor right"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" ]; key = "up"; dispatcher = "focusmonitor"; argument = "u"; description = "Focus monitor up"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" ]; key = "down"; dispatcher = "focusmonitor"; argument = "d"; description = "Focus monitor down"; category = "Monitors"; }

    { modifiers = [ "SUPER" "CTRL" "SHIFT" ]; key = "left"; dispatcher = "movewindow"; argument = "mon:l"; description = "Move window to monitor left"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" "SHIFT" ]; key = "right"; dispatcher = "movewindow"; argument = "mon:r"; description = "Move window to monitor right"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" "SHIFT" ]; key = "up"; dispatcher = "movewindow"; argument = "mon:u"; description = "Move window to monitor up"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" "SHIFT" ]; key = "down"; dispatcher = "movewindow"; argument = "mon:d"; description = "Move window to monitor down"; category = "Monitors"; }

    { modifiers = [ "SUPER" "CTRL" "ALT" ]; key = "left"; dispatcher = "swapactiveworkspaces"; argument = "current -1"; description = "Swap workspace left"; category = "Monitors"; }
    { modifiers = [ "SUPER" "CTRL" "ALT" ]; key = "right"; dispatcher = "swapactiveworkspaces"; argument = "current +1"; description = "Swap workspace right"; category = "Monitors"; }

    # SwayOSD volume / brightness (repeatable)
    { modifiers = [ ]; key = "XF86AudioRaiseVolume"; phase = "repeat"; repeat = true; dispatcher = "exec"; argument = "swayosd-client --output-volume raise"; description = "Volume up"; category = "Media"; }
    { modifiers = [ ]; key = "XF86AudioLowerVolume"; phase = "repeat"; repeat = true; dispatcher = "exec"; argument = "swayosd-client --output-volume lower"; description = "Volume down"; category = "Media"; }
    { modifiers = [ ]; key = "XF86AudioMute"; dispatcher = "exec"; argument = "swayosd-client --output-volume mute-toggle"; description = "Mute"; category = "Media"; }
    { modifiers = [ ]; key = "XF86AudioMicMute"; dispatcher = "exec"; argument = "swayosd-client --input-volume mute-toggle"; description = "Mic mute"; category = "Media"; }
    { modifiers = [ ]; key = "XF86MonBrightnessUp"; phase = "repeat"; repeat = true; dispatcher = "exec"; argument = "swayosd-client --brightness raise"; description = "Brightness up"; category = "Media"; }
    { modifiers = [ ]; key = "XF86MonBrightnessDown"; phase = "repeat"; repeat = true; dispatcher = "exec"; argument = "swayosd-client --brightness lower"; description = "Brightness down"; category = "Media"; }

    { modifiers = [ ]; key = "XF86AudioPlay"; dispatcher = "exec"; argument = "playerctl play-pause"; description = "Play/Pause"; category = "Media"; }
    { modifiers = [ ]; key = "XF86AudioPause"; dispatcher = "exec"; argument = "playerctl play-pause"; description = "Pause"; category = "Media"; }
    { modifiers = [ ]; key = "XF86AudioNext"; dispatcher = "exec"; argument = "playerctl next"; description = "Next track"; category = "Media"; }
    { modifiers = [ ]; key = "XF86AudioPrev"; dispatcher = "exec"; argument = "playerctl previous"; description = "Previous track"; category = "Media"; }

    { modifiers = [ ]; key = "Caps_Lock"; phase = "release"; dispatcher = "exec"; argument = "swayosd-client --caps-lock"; description = "CapsLock OSD"; category = "Media"; }

    # Mouse bindings
    { modifiers = [ "SUPER" ]; key = "mouse:272"; mouse = true; dispatcher = "movewindow"; description = "Move window"; category = "Mouse"; }
    { modifiers = [ "SUPER" ]; key = "mouse:273"; mouse = true; dispatcher = "resizewindow"; description = "Resize window"; category = "Mouse"; }
    { modifiers = [ "ALT" ]; key = "mouse:272"; mouse = true; dispatcher = "resizewindow"; description = "Resize window (Alt)"; category = "Mouse"; }
  ] ++ lib.optionals vars.features.gaming [
    { modifiers = [ "SUPER" "SHIFT" ]; key = "G"; dispatcher = "exec"; argument = "gaming-mode toggle"; description = "Toggle gaming profile"; category = "Gaming"; }
  ];

  entries = map bindEntry bindDefinitions;

  collisionKey = entry:
    "${modsToHypr entry.modifiers},${entry.key},${activationGroup entry}";

  groupedByCollision = lib.groupBy collisionKey entries;

  # A collision group shares canonical mods + key + activation group.
  # Any repetition is forbidden, EXCEPT an explicitly marked chain where every
  # entry has `chain = true` (e.g. SUPER+Tab: cyclenext then bringactivetotop).
  groupHasConflict = group:
    if builtins.length group <= 1 then false
    else !(builtins.all (entry: entry.chain) group);

  conflictingGroups = lib.filter groupHasConflict (lib.attrValues groupedByCollision);
  hasCollisions = conflictingGroups != [ ];

  duplicateKeys = map (group: collisionKey (builtins.head group)) conflictingGroups;

  collisionError =
    if hasCollisions then
      "Duplicate Hyprland keybinds detected: ${lib.concatStringsSep ", " duplicateKeys}"
    else null;

  toBindLine = entry:
    let
      mods = modsToHypr entry.modifiers;
      argPart = if entry.argument != "" then ", ${entry.argument}" else "";
    in
      "${mods}, ${entry.key}, ${entry.dispatcher}${argPart}";

  grouped = lib.groupBy (entry: directiveName entry) entries;

  hyprBinds = directive: map toBindLine (grouped.${directive} or [ ]);

  cheatsheetByCategory =
    lib.groupBy (entry: entry.category) entries;

  cheatsheetText =
    lib.concatStringsSep "\n\n" (
      lib.mapAttrsToList (
        category: binds:
          "## ${category}\n" +
          lib.concatStringsSep "\n" (
            map (
              entry:
                "${modsToHypr entry.modifiers} + ${entry.key}  →  ${entry.description}"
            ) binds
          )
      ) cheatsheetByCategory
    );

in
{
  inherit entries cheatsheetText collisionError;
  bind = hyprBinds "bind";
  binde = hyprBinds "binde";
  bindl = hyprBinds "bindl";
  bindel = hyprBinds "bindel";
  bindr = hyprBinds "bindr";
  bindrl = hyprBinds "bindrl";
  bindm = hyprBinds "bindm";
}
