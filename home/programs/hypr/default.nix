{ config, lib, pkgs, vars, colors, browser, inputs, ... }:

let
  rgba = colors.toRgba;

  # Wallpaper domain bridge only: curated Gallery wallpapers as a read-only
  # store dir. GTK/icon asset selection lives in the themes domain
  # (home/themes/default.nix), not here.
  galleryThemes = import ../../themes/gallery { inherit lib inputs; };
  galleryWallpaperDir = galleryThemes.wallpaperDirFor vars.theme;

  keybinds = import ./keybinds.nix { inherit lib vars; };
  wallpaper = import ./wallpaper.nix { inherit pkgs vars galleryWallpaperDir; };
  gaming = import ./gaming-mode.nix { inherit pkgs vars lib; };

  cheatsheetFile = pkgs.writeText "hypr-cheatsheet.txt" keybinds.cheatsheetText;
  cheatsheet = pkgs.writeShellApplication {
    name = "cheatsheet";
    runtimeInputs = with pkgs; [ rofi-wayland coreutils ];
    text = ''
      rofi -dmenu -i -p "Keybinds" < ${cheatsheetFile} || true
    '';
  };

  # Waybar show/hide toggle. Uses SIGUSR1 (Waybar's built-in visibility toggle)
  # instead of stopping the systemd unit, so rapid presses never trip the
  # systemd start-limit (which previously left Waybar dead and unresponsive).
  waybar-toggle = pkgs.writeShellApplication {
    name = "waybar-toggle";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      set -euo pipefail
      if systemctl --user is-active --quiet waybar.service; then
        systemctl --user kill -s SIGUSR1 waybar.service
      else
        systemctl --user reset-failed waybar.service 2>/dev/null || true
        systemctl --user start waybar.service
      fi
    '';
  };

  # Full restart of the Waybar unit. reset-failed first so repeated presses do
  # not hit the systemd start-limit and leave the unit in a failed state.
  waybar-restart = pkgs.writeShellApplication {
    name = "waybar-restart";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      set -euo pipefail
      systemctl --user reset-failed waybar.service 2>/dev/null || true
      systemctl --user restart waybar.service
    '';
  };

  # Scratchpad round-trip: send active window to special:magic or return it to the
  # focused monitor's active workspace (movetoworkspacesilent, no workspace switch).
  scratchpad-toggle = pkgs.writeShellApplication {
    name = "scratchpad-toggle";
    runtimeInputs = with pkgs; [ hyprland jq coreutils ];
    text = ''
      set -euo pipefail
      win=$(hyprctl activewindow -j)
      addr=$(printf '%s' "$win" | jq -r '.address // empty')
      if [ -z "$addr" ] || [ "$addr" = "null" ]; then
        exit 0
      fi
      ws=$(printf '%s' "$win" | jq -r '.workspace.name // empty')
      if [ "$ws" = "special:magic" ]; then
        target=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .activeWorkspace.id')
        hyprctl dispatch movetoworkspacesilent "$target,address:$addr"
      else
        hyprctl dispatch movetoworkspacesilent "special:magic,address:$addr"
      fi
    '';
  };

  # Opacity control scripts - using temp files to track per-window opacity
  opacity-increase = pkgs.writeShellScriptBin "opacity-increase" ''
    ADDR=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.address')
    if [ "$ADDR" = "null" ] || [ -z "$ADDR" ]; then exit 0; fi

    # Create dir for opacity files
    mkdir -p /tmp/hypr_opacity
    OPACITY_FILE="/tmp/hypr_opacity/$ADDR"

    # Read current opacity or default to 1.0
    if [ -f "$OPACITY_FILE" ]; then
      CURRENT=$(cat "$OPACITY_FILE")
    else
      CURRENT="1.0"
    fi

    # Calculate new opacity (max 1.0)
    NEW=$(${pkgs.bc}/bin/bc <<< "scale=2; $CURRENT + 0.05")
    if [ "$(${pkgs.bc}/bin/bc <<< "$NEW > 1.0")" = "1" ]; then
      NEW="1.0"
    fi

    # Save and apply
    echo "$NEW" > "$OPACITY_FILE"
    hyprctl setprop address:$ADDR alpha "$NEW" locked
    PERCENT=$(${pkgs.bc}/bin/bc <<< "scale=0; $NEW * 100 / 1")
    ${pkgs.libnotify}/bin/notify-send -r 9999 "Opacity" "$PERCENT%" -t 1000
  '';

  opacity-decrease = pkgs.writeShellScriptBin "opacity-decrease" ''
    ADDR=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.address')
    if [ "$ADDR" = "null" ] || [ -z "$ADDR" ]; then exit 0; fi

    mkdir -p /tmp/hypr_opacity
    OPACITY_FILE="/tmp/hypr_opacity/$ADDR"

    if [ -f "$OPACITY_FILE" ]; then
      CURRENT=$(cat "$OPACITY_FILE")
    else
      CURRENT="1.0"
    fi

    # Calculate new opacity (min 0.2)
    NEW=$(${pkgs.bc}/bin/bc <<< "scale=2; $CURRENT - 0.05")
    if [ "$(${pkgs.bc}/bin/bc <<< "$NEW < 0.2")" = "1" ]; then
      NEW="0.2"
    fi

    echo "$NEW" > "$OPACITY_FILE"
    hyprctl setprop address:$ADDR alpha "$NEW" locked
    PERCENT=$(${pkgs.bc}/bin/bc <<< "scale=0; $NEW * 100 / 1")
    ${pkgs.libnotify}/bin/notify-send -r 9999 "Opacity" "$PERCENT%" -t 1000
  '';

  opacity-reset = pkgs.writeShellScriptBin "opacity-reset" ''
    ADDR=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.address')
    if [ "$ADDR" = "null" ] || [ -z "$ADDR" ]; then exit 0; fi

    mkdir -p /tmp/hypr_opacity
    OPACITY_FILE="/tmp/hypr_opacity/$ADDR"

    echo "1.0" > "$OPACITY_FILE"
    hyprctl setprop address:$ADDR alpha 1.0 locked
    ${pkgs.libnotify}/bin/notify-send -r 9999 "Opacity" "Reset to 100%" -t 1000
  '';

  # Script to show/hide dock based on workspace windows (multi-monitor aware)
  dock-watcher = pkgs.writeShellScriptBin "dock-watcher" ''
    check_and_toggle() {
      # Get focused monitor and its active workspace
      FOCUSED=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.focused == true)')
      MONITOR_NAME=$(echo "$FOCUSED" | ${pkgs.jq}/bin/jq -r '.name')
      WORKSPACE=$(echo "$FOCUSED" | ${pkgs.jq}/bin/jq -r '.activeWorkspace.id')

      # Count windows on current workspace (excluding special workspaces)
      WINDOW_COUNT=$(hyprctl clients -j | ${pkgs.jq}/bin/jq --arg ws "$WORKSPACE" '[.[] | select(.workspace.id == ($ws | tonumber))] | length')
      
      # Get dock PID (using -f for partial match)
      DOCK_PID=$(${pkgs.procps}/bin/pgrep -f "nwg-dock-hyprland" | head -1)
      
      if [ -n "$DOCK_PID" ]; then
        if [ "$WINDOW_COUNT" -eq 0 ]; then
          # No windows - show dock (signal 36 = SIGRTMIN+2)
          kill -36 "$DOCK_PID" 2>/dev/null
        else
          # Has windows - hide dock (signal 37 = SIGRTMIN+3)
          kill -37 "$DOCK_PID" 2>/dev/null
        fi
      fi
    }

    # Initial check
    sleep 2
    check_and_toggle

    # Listen to Hyprland events using correct socket path
    SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCKET_PATH" | while read -r line; do
      case "$line" in
        openwindow*|closewindow*|movewindow*|workspace*|destroyworkspace*|createworkspace*|focusedmon*)
          sleep 0.1
          check_and_toggle
          ;;
      esac
    done
  '';
in
if keybinds.collisionError != null then throw keybinds.collisionError else {
  home-manager.users.${vars.username} = {
    imports = [
      ./hyprland-environment.nix
    ];

    # sd-switch restarts user units when X-Restart-Triggers change (waybar, swaync, ags).
    systemd.user.startServices = true;

    home.packages = with pkgs; [
      swww
      mpvpaper        # Video wallpapers
      hyprpaper
      hyprpicker      # Color picker
      hypridle        # Idle daemon
      hyprlock        # Lock screen
      wlogout         # Logout menu
      libnotify       # For notifications

      # Desktop icons/launchers
      nwg-drawer      # Full-screen app drawer
      nwg-dock-hyprland  # Dock panel for Hyprland

      jq              # JSON parser for scripts
      bc              # Calculator for scripts
      procps          # pkill command
      socat           # For dock-watcher (Hyprland socket)

      waybar-toggle
      waybar-restart
      scratchpad-toggle
      opacity-increase
      opacity-decrease
      opacity-reset
      dock-watcher

      cheatsheet
    ] ++ wallpaper.packages
      ++ lib.optional vars.features.gaming gaming.package;

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      xwayland.enable = true;

      settings = {
        # Monitor configuration - uses vars
        # Supports main monitor + additional monitors from vars.nix
        monitor = [ vars.monitor ] ++ vars.additionalMonitors;

        # Workspace to monitor bindings (for multi-monitor setups)
        workspace = vars.workspaceMonitorBindings;

        # Variables
        "$terminal" = vars.terminal;
        "$browser" = browser.bin;
        "$menu" = "rofi -show drun -show-icons";
        "$fileManager" = "thunar";
        "$mainMod" = "SUPER";

        # Environment variables
        env = [
            "XCURSOR_SIZE,24"
            "GDK_BACKEND,wayland,x11"
            "QT_QPA_PLATFORM,wayland;xcb"
            # SDL с fallback на x11 для игр через Proton
            "SDL_VIDEODRIVER,wayland,x11"
            "CLUTTER_BACKEND,wayland"
            "XDG_CURRENT_DESKTOP,Hyprland"
            "XDG_SESSION_TYPE,wayland"
            "XDG_SESSION_DESKTOP,Hyprland"
            # XWayland DISPLAY для Steam/Proton игр
            "DISPLAY,:0"
        ];

        # Autostart applications (waybar, swaync, ags are systemd user services).
        exec-once =
          [
            "hyprctl setcursor Bibata-Modern-Classic 24"
            "xhost +local:"
            "swww-daemon"
            browser.bin
            "nm-applet"
            "udiskie"
            "blueman-applet"
            "nwg-dock-hyprland -r -i 48 -mb 8"
            "dock-watcher"
            "sleep 1 && wallpaper-startup"
          ];

        # Input configuration
        input = {
          kb_layout = vars.kbLayouts;
          kb_options = vars.kbOptions;
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = false;
          };
        };

        # General settings - using dynamic theme colors
        general = {
          gaps_in = 4;
          gaps_out = 12;
          border_size = 2;
          "col.active_border" = colors.hyprland.activeBorder;
          "col.inactive_border" = colors.hyprland.inactiveBorder;
          layout = "dwindle";
          allow_tearing = false;
        };

        decoration = {
          rounding = 14;
          blur = {
            enabled = true;
            size = 8;
            passes = 3;
            new_optimizations = true;
            ignore_opacity = true;
            noise = 0.01;
            contrast = 0.9;
            brightness = 0.85;
          };
          shadow = {
            enabled = true;
            range = 10;
            render_power = 2;
            color = colors.hyprland.shadow;
          };
        };

        animations = {
          enabled = true;
          bezier = [
            "ease,0.4,0.02,0.21,1"
            "overshot,0.13,0.99,0.29,1.1"
            "smoothOut,0.36,0,0.66,-0.56"
            "smoothIn,0.25,1,0.5,1"
          ];
          animation = [
            "windows,1,4,overshot,slide"
            "windowsOut,1,4,smoothOut,slide"
            "windowsMove,1,4,default"
            "border,1,10,default"
            "borderangle,1,8,default"
            "fade,1,3,smoothIn"
            "fadeDim,1,3,smoothIn"
            "workspaces,1,4,overshot,slidevert"
          ];
        };

        # Layouts
        dwindle = {
          pseudotile = true;
          preserve_split = true;
          smart_split = true;
          smart_resizing = true;
        };

        master = {
          new_status = "master";
        };

        # Gestures
        # gestures = {
        #   workspace_swipe = true;
        #   workspace_swipe_fingers = 3;
        # };

        # Misc
        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
          vfr = true;
          # Окно открывается на том workspace, где было запущено (не где сейчас пользователь)
          # 0 = disabled, 1 = single-shot, 2 = persistent (отслеживает до появления окна)
          # initial_workspace_tracking = 2;
        };

        # Window rules
        windowrulev2 = [
          "float,class:^(floating)$"
          "center,class:^(floating)$"
          "size 800 500,class:^(floating)$"
          "float,class:^(kitty)$"
          "center,class:^(kitty)$"
          "size 800 600,class:^(kitty)$"
          "float,class:^(pavucontrol)$"
          "float,class:^(blueman-manager)$"
          "float,class:^(nm-connection-editor)$"
          "float,class:^(mpv)$"
          "center,class:^(mpv)$"
          "size 960 540,class:^(mpv)$"
          "float,title:^(Picture-in-Picture)$"
          "pin,title:^(Picture-in-Picture)$"
          "float,class:^(imv)$"
          "float,class:^(Rofi)$"
          "animation popin,class:^(Rofi)$"
          "float,title:^(File Operation Progress)$"
          "float,class:^(xdg-desktop-portal-gtk)$"

          # Steam games - Proton/Wine игры
          "workspace 5 silent,class:^(steam_app_.*)$"
          "fullscreen,class:^(steam_app_.*)$"
          # Gamescope
          "workspace 5 silent,class:^(gamescope)$"
          "fullscreen,class:^(gamescope)$"

          # Native Linux games (добавляйте сюда свои игры)
          # War Thunder
          "workspace 5 silent,class:^(War Thunder.*)$"
          "fullscreen,class:^(War Thunder.*)$"
          # Counter-Strike 2
          "workspace 5 silent,class:^(cs2)$"
          "fullscreen,class:^(cs2)$"
          # Dota 2
          "workspace 5 silent,class:^(dota2)$"
          "fullscreen,class:^(dota2)$"

          # Steam клиент - окна настроек и т.д.
          "stayfocused,title:^()$,class:^(steam)$"
          "minsize 1 1,title:^()$,class:^(steam)$"

          # ===== Wine/Lutris/Bottles игры =====
          # World of Tanks / Мир Танков (через Wine/Bottles)
          "workspace 5 silent,class:^(worldoftanks.*)$"
          "fullscreen,class:^(worldoftanks.*)$"
          "immediate,class:^(worldoftanks.*)$"
          "nofocus,class:^(worldoftanks.*)$,title:^$"

          # Wine приложения общие правила
          "workspace 5,class:^(wine)$"
          "workspace 5,class:^(Wine)$"
          "workspace 5,class:^(.*.exe)$"

          # Lesta Game Center (WoT launcher)
          "float,class:^(lgc.exe)$"
          "center,class:^(lgc.exe)$"
          "size 1280 720,class:^(lgc.exe)$"

          # Bottles app windows
          "float,class:^(com.usebottles.bottles)$"
          "center,class:^(com.usebottles.bottles)$"

          # Lutris
          "float,class:^(lutris)$"
          "center,class:^(lutris)$"

          # Предотвращение минимизации Wine окон
          "noinitialfocus,class:^(.*[Ww]ine.*)$"
          "stayfocused,class:^(.*[Ww]ine.*)$,title:^(?!.*[Mm]enu).*$"

          # XWayland Wine windows - не терять фокус
          "stayfocused,class:^(.*\.exe)$"
          "stayfocused,class:^(.*\.[Ee][Xx][Ee])$"

          # Note: For background-only transparency (not affecting text):
          # - Kitty: use Ctrl+Shift+A then M/L/1/D to change opacity
          # - VS Code: install "Custom CSS and JS Loader" extension
        ];

        bind = keybinds.bind;
        binde = keybinds.binde;
        bindl = keybinds.bindl;
        bindel = keybinds.bindel;
        bindr = keybinds.bindr;
        bindrl = keybinds.bindrl;
        bindm = keybinds.bindm;
      };
    };

    home.activation.initWallpaperSymlinks = wallpaper.initWallpaperSymlinksScript;

    # Animated wallpaper is a single systemd-managed mpvpaper instance recycled
    # every 45 min to bound RSS growth (see wallpaper.nix / README).
    systemd.user.services.animated-wallpaper = wallpaper.animatedWallpaperService;

    # Hyprlock configuration - using dynamic theme colors
    # Multi-monitor: empty monitor = applies to all monitors
    home.file.".config/hypr/hyprlock.conf".text = let
      # Remove # from hex colors for hyprlock rgb() format
      toRgb = color: builtins.substring 1 6 color;
    in ''
      # General settings for multi-monitor
      general {
        hide_cursor = true
        grace = 0
        no_fade_in = false
        no_fade_out = false
      }

      # Background on all monitors (empty monitor = all)
      background {
        monitor =
        path = ${wallpaper.lockSymlink}
        blur_passes = 4
        blur_size = 8
        noise = 0.02
        contrast = 0.9
        brightness = 0.6
        vibrancy = 0.2
      }

      # Time (large, centered) - on all monitors
      label {
        monitor =
        text = cmd[update:1000] echo "$(date +'%H:%M')"
        color = rgba(${toRgb colors.colors.text}, 1.0)
        font_size = 100
        font_family = JetBrainsMono Nerd Font Bold
        position = 0, 180
        halign = center
        valign = center
        shadow_passes = 2
        shadow_size = 3
      }

      # Date - on all monitors
      label {
        monitor =
        text = cmd[update:60000] echo "$(date +'%A, %d %B')"
        color = rgba(${toRgb colors.colors.subtext1}, 0.9)
        font_size = 22
        font_family = JetBrainsMono Nerd Font
        position = 0, 80
        halign = center
        valign = center
      }

      # Greeting - on all monitors
      label {
        monitor =
        text = Hi, ${vars.username} 
        color = rgba(${toRgb colors.colors.accent}, 1.0)
        font_size = 18
        font_family = JetBrainsMono Nerd Font Bold
        position = 0, -20
        halign = center
        valign = center
      }

      # Keyboard layout indicator - bottom right, short code (US/RU) with icon
      label {
        monitor =
        text = cmd[update:500] L=$(hyprctl devices -j | jq -r 'first(.keyboards[]|select(.main)|.active_keymap) // "US"'); case "$L" in *ussian*) echo "⌨  RU";; *nglish*) echo "⌨  US";; *) echo "⌨  $(printf %s "$L" | cut -c1-2 | tr a-z A-Z)";; esac
        color = rgba(${toRgb colors.colors.accent}, 0.95)
        font_size = 18
        font_family = JetBrainsMono Nerd Font Bold
        position = -40, 40
        halign = right
        valign = bottom
      }

      # Password input field - on all monitors
      input-field {
        monitor =
        size = 280, 55
        outline_thickness = 3
        dots_size = 0.5
        dots_spacing = 0.35
        dots_center = true
        dots_rounding = -1
        outer_color = rgba(${toRgb colors.colors.accent}, 0.9)
        inner_color = rgba(${toRgb colors.colors.surface1}, 0.97)
        font_color = rgb(${toRgb colors.colors.text})
        fade_on_empty = false
        fade_timeout = 1000
        placeholder_text = <i><span foreground="##${toRgb colors.colors.subtext0}">🔒 Password...</span></i>
        hide_input = false
        rounding = 14
        check_color = rgb(${toRgb colors.colors.green})
        fail_color = rgb(${toRgb colors.colors.red})
        fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
        fail_transition = 300
        capslock_color = rgb(${toRgb colors.colors.yellow})
        position = 0, -140
        halign = center
        valign = center
      }
    '';

    # Hypridle configuration
    home.file.".config/hypr/hypridle.conf".text = ''
      general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
      }

      listener {
        timeout = 300
        on-timeout = brightnessctl -s set 30
        on-resume = brightnessctl -r
      }

      listener {
        timeout = 600
        on-timeout = loginctl lock-session
      }

      listener {
        timeout = 900
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }

      listener {
        timeout = 1800
        on-timeout = systemctl suspend
      }
    '';

    # nwg-drawer configuration - using dynamic theme colors
    home.file.".config/nwg-drawer/drawer.css".text = ''
      window {
        background-color: ${rgba colors.colors.base 0.9};
        color: ${colors.colors.text};
      }

      /* search entry */
      entry {
        background-color: ${rgba colors.colors.surface0 0.8};
        border-radius: 14px;
        border: 2px solid ${rgba colors.colors.accent 0.3};
        color: ${colors.colors.text};
        margin: 10px;
        padding: 10px;
      }

      entry:focus {
        border-color: ${colors.colors.accent};
      }

      button, image {
        background: none;
        border: none;
        color: ${colors.colors.text};
      }

      button:hover {
        background-color: ${rgba colors.colors.surface1 0.8};
        border-radius: 8px;
      }

      /* categories sidebar */
      #categories-box button {
        background-color: transparent;
        border-radius: 8px;
        margin: 2px 5px;
        padding: 5px 10px;
      }

      #categories-box button:hover {
        background-color: ${rgba colors.colors.accent 0.2};
      }

      /* pinned apps box */
      #pinned-box {
        background-color: ${rgba colors.colors.surface0 0.5};
        border-radius: 14px;
        margin: 10px;
        padding: 10px;
      }

      /* app grid */
      #apps-grid button {
        background-color: transparent;
        border-radius: 14px;
        padding: 10px;
        margin: 5px;
      }

      #apps-grid button:hover {
        background-color: ${rgba colors.colors.accent 0.2};
      }

      #apps-grid button label {
        color: ${colors.colors.text};
        font-size: 12px;
      }
    '';

    # nwg-dock configuration - using dynamic theme colors
    home.file.".config/nwg-dock-hyprland/style.css".text = ''
      window {
        background: ${rgba colors.colors.base 0.75};
        border-radius: 14px;
        border: 2px solid ${rgba colors.colors.accent 0.3};
        padding: 4px;
      }

      #box {
        padding: 4px;
      }

      button {
        background: transparent;
        border-radius: 14px;
        padding: 6px;
        margin: 2px;
        border: none;
      }

      button:hover {
        background-color: ${rgba colors.colors.accent 0.25};
      }

      button:focus {
        box-shadow: none;
      }

      image {
        padding: 4px;
      }
    '';
  };
}
