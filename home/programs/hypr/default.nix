{ config, lib, pkgs, vars, colors, ... }:

let
  rgba = colors.toRgba;
  
  # Script to set random animated/video wallpaper using mpvpaper
  wallpaper-animated = pkgs.writeShellScriptBin "wallpaper-animated" ''
  WALLPAPER_DIR="${vars.homeDirectory}/${vars.animatedWallpapersDir}"

  if [ -d "$WALLPAPER_DIR" ] && [ "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.gif" -o -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) 2>/dev/null | shuf -n 1)

    if [ -n "$WALLPAPER" ]; then
      # Аккуратно убиваем старый mpvpaper
      ${pkgs.procps}/bin/pkill -f mpvpaper 2>/dev/null || true
      sleep 0.5

      # Опции mpv для живых обоев
      MPV_OPTS="no-audio loop \
        --hwdec=no \
        --no-cache \
        --profile=low-latency \
        --vd-lavc-threads=1 \
        --video-sync=display-resample \
        --no-config"

      ${pkgs.mpvpaper}/bin/mpvpaper -o "$MPV_OPTS" '*' "$WALLPAPER" &

      ${pkgs.libnotify}/bin/notify-send \
        "Animated Wallpaper" "$(basename "$WALLPAPER")" -t 2000
    fi
  fi
  '';

  # Script to set random static wallpaper using swww
  wallpaper-static = pkgs.writeShellScriptBin "wallpaper-static" ''
    WALLPAPER_DIR="${vars.homeDirectory}/${vars.staticWallpapersDir}"

    # Kill mpvpaper if running (switch back to static)
    pkill -x mpvpaper 2>/dev/null

    # Ensure swww is initialized
    ${pkgs.swww}/bin/swww init 2>/dev/null || true

    if [ -d "$WALLPAPER_DIR" ] && [ "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
      WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) 2>/dev/null | shuf -n 1)
      if [ -n "$WALLPAPER" ]; then
        ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type random --transition-fps 60 --transition-duration 2
        ${pkgs.libnotify}/bin/notify-send "Static Wallpaper" "$(basename "$WALLPAPER")" -t 2000
      fi
    fi
  '';

  # Script to cycle wallpapers - static only (for compatibility)
  wallpaper-next = pkgs.writeShellScriptBin "wallpaper-next" ''
    STATIC_DIR="${vars.homeDirectory}/${vars.staticWallpapersDir}"

    # Kill mpvpaper if running
    pkill -x mpvpaper 2>/dev/null

    # Ensure swww is initialized (needed when animated wallpaper was used at startup)
    ${pkgs.swww}/bin/swww init 2>/dev/null || true

    # Get only static images
    ALL_WALLPAPERS=$(find "$STATIC_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) 2>/dev/null)

    if [ -n "$ALL_WALLPAPERS" ]; then
      WALLPAPER=$(echo "$ALL_WALLPAPERS" | shuf -n 1)
      ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type random --transition-fps 60 --transition-duration 2
      ${pkgs.libnotify}/bin/notify-send "Wallpaper" "$(basename "$WALLPAPER")" -t 2000
    else
      ${pkgs.libnotify}/bin/notify-send "Wallpaper" "No images in $STATIC_DIR (add jpg/png/webp/gif)" -t 3000 -u critical
    fi
  '';

  # Waybar watcher script
  waybar-watcher = pkgs.writeShellScriptBin "waybar-watcher" ''
    while true; do
      ${pkgs.waybar}/bin/waybar &
      WAYBAR_PID=$!
      ${pkgs.inotify-tools}/bin/inotifywait -e modify ~/.config/waybar/config ~/.config/waybar/style.css 2>/dev/null
      kill $WAYBAR_PID 2>/dev/null
      sleep 0.5
    done
  '';

  # Waybar toggle script
  waybar-toggle = pkgs.writeShellScriptBin "waybar-toggle" ''
    if pgrep -x "waybar" > /dev/null; then
      pkill waybar
    else
      ${pkgs.waybar}/bin/waybar &
    fi
  '';

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
{
  home-manager.users.${vars.username} = {
    imports = [
      ./hyprland-environment.nix
    ];

    home.packages = with pkgs; [
      waybar
      swww
      mpvpaper        # Video wallpapers
      hyprpaper
      hyprpicker      # Color picker
      hypridle        # Idle daemon
      hyprlock        # Lock screen
      wlogout         # Logout menu
      inotify-tools   # For waybar watcher
      libnotify       # For notifications

      # Desktop icons/launchers
      nwg-drawer      # Full-screen app drawer
      nwg-dock-hyprland  # Dock panel for Hyprland

      jq              # JSON parser for scripts
      bc              # Calculator for scripts
      procps          # pkill command
      socat           # For dock-watcher (Hyprland socket)

      # Custom wallpaper scripts
      wallpaper-animated
      wallpaper-static
      wallpaper-next
      waybar-watcher
      waybar-toggle

      # Opacity control scripts
      opacity-increase
      opacity-decrease
      opacity-reset

      # Dock watcher script
      dock-watcher
    ];

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
        "$browser" = vars.browser;
        "$menu" = "rofi -show drun -show-icons";
        "$fileManager" = "thunar";
        "$mainMod" = "SUPER";

        # Environment variables
        env = [
            "XCURSOR_SIZE,24"
            "QT_QPA_PLATFORMTHEME,qt5ct"
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

        # Autostart applications
        exec-once = [
            "hyprctl setcursor Bibata-Modern-Classic 24"
            # Разрешить доступ к XWayland для локальных подключений (критично для Steam/Proton)
            "xhost +local:"
            "swww-daemon"
            "swaync"
            "floorp"
            "nm-applet"
            "udiskie"
            "blueman-applet"
            "waybar-watcher"
            # AGS widgets daemon (if enabled in vars.nix)
            "ags"
            # Dock panel (resident mode, follows active output for multi-monitor)
            # -f = follow active output (multi-monitor support)
            # -r = resident mode (always running)
            "nwg-dock-hyprland -r -f -i 48 -mb 8 -ml 8 -mr 8"
            # Dock watcher - shows dock only on empty workspaces
            "dock-watcher"
            # Set animated wallpaper on startup (fallback to static if no animated found)
            "sleep 1 && wallpaper-animated || wallpaper-static"
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
          gaps_in = 5;
          gaps_out = 15;
          border_size = 2;
          "col.active_border" = colors.hyprland.activeBorder;
          "col.inactive_border" = colors.hyprland.inactiveBorder;
          layout = "dwindle";
          allow_tearing = false;
        };

        # Decoration
        decoration = {
          rounding = 12;
          blur = {
            enabled = true;
            size = 10;
            passes = 3;
            new_optimizations = true;
            ignore_opacity = true;
            noise = 0.01;
            contrast = 0.9;
            brightness = 0.8;
          };
          shadow = {
            enabled = true;
            range = 12;
            render_power = 3;
            color = colors.hyprland.shadow;
          };
        };

        # Animations
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
            "workspaces,1,5,overshot,slidevert"
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

        # Key bindings
        bind = [
          # Applications
          "$mainMod, Return, exec, $terminal"
          "$mainMod, C, exec, $terminal"
          "$mainMod, E, exec, $fileManager"
          "$mainMod, L, exec, $browser"
          "$mainMod, R, exec, $menu"
          "$mainMod, W, exec, rofi -show drun -show-icons"
          "$mainMod, G, exec, rofi -modi games -show games -show-icons -theme games"
          "$mainMod, A, exec, nwg-drawer"  # Full-screen app drawer

          # Window management
          "$mainMod, Q, killactive,"
          "$mainMod, V, togglefloating,"
          "$mainMod, F, fullscreen, 1"
          "$mainMod, P, pseudo,"
          "$mainMod, J, togglesplit,"
          "$mainMod, M, exit,"

          # Screenshots
          "$mainMod, F12, exec, grim -g \"$(slurp)\" - | wl-copy"
          ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
          "SHIFT, Print, exec, grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
          "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | swappy -f -"

          # Waybar toggle
          "$mainMod, B, exec, waybar-toggle"
          "$mainMod SHIFT, B, exec, pkill waybar"

          # Wallpaper controls
          "$mainMod SHIFT, W, exec, wallpaper-next"
          "$mainMod ALT, W, exec, wallpaper-animated"

          # Color picker
          "$mainMod SHIFT, C, exec, hyprpicker -a"

          # Opacity controls (for active window)
          "$mainMod ALT, equal, exec, opacity-increase"
          "$mainMod ALT, minus, exec, opacity-decrease"
          "$mainMod ALT, 0, exec, opacity-reset"

          # Lock screen
          "$mainMod SHIFT, L, exec, hyprlock"

          # Clipboard history
          "$mainMod SHIFT, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"

          # Notification center (SwayNC)
          "$mainMod, N, exec, swaync-client -t -sw"
          "$mainMod SHIFT, N, exec, swaync-client -d -sw"

          # Focus movement
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"

          # Window cycling
          "$mainMod, Tab, cyclenext,"
          "$mainMod, Tab, bringactivetotop,"

          # Workspace switching
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"

          # Move windows to workspaces
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
          "$mainMod SHIFT, 0, movetoworkspace, 10"

          # Scroll through workspaces
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"

          # Special workspace (scratchpad)
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"

          # Multi-monitor controls
          # Focus monitor by direction
          "$mainMod CTRL, left, focusmonitor, l"
          "$mainMod CTRL, right, focusmonitor, r"
          "$mainMod CTRL, up, focusmonitor, u"
          "$mainMod CTRL, down, focusmonitor, d"

          # Move window to monitor by direction
          "$mainMod CTRL SHIFT, left, movewindow, mon:l"
          "$mainMod CTRL SHIFT, right, movewindow, mon:r"
          "$mainMod CTRL SHIFT, up, movewindow, mon:u"
          "$mainMod CTRL SHIFT, down, movewindow, mon:d"

          # Swap workspaces between monitors
          "$mainMod CTRL ALT, left, swapactiveworkspaces, current -1"
          "$mainMod CTRL ALT, right, swapactiveworkspaces, current +1"
        ];

        # Repeatable binds
        binde = [
          # Volume control
          ", XF86AudioRaiseVolume, exec, pamixer -i 5"
          ", XF86AudioLowerVolume, exec, pamixer -d 5"
          ", XF86AudioMute, exec, pamixer -t"
          ", XF86AudioMicMute, exec, pamixer --default-source -t"

          # Brightness control
          ", XF86MonBrightnessUp, exec, brightnessctl s +10%"
          ", XF86MonBrightnessDown, exec, brightnessctl s 10%-"

          # Media control
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPause, exec, playerctl play-pause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"
        ];

        # Mouse bindings
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
          "ALT, mouse:272, resizewindow"
        ];
      };
    };

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
        path = ${vars.homeDirectory}/${vars.staticWallpapersDir}/${vars.defaultWallpaper}
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
        font_size = 16
        font_family = JetBrainsMono Nerd Font
        position = 0, -60
        halign = center
        valign = center
      }

      # Password input field - on all monitors
      input-field {
        monitor =
        size = 260, 50
        outline_thickness = 3
        dots_size = 0.3
        dots_spacing = 0.15
        dots_center = true
        dots_rounding = -1
        outer_color = rgba(${toRgb colors.colors.accent}, 0.5)
        inner_color = rgba(${toRgb colors.colors.base}, 0.85)
        font_color = rgb(${toRgb colors.colors.text})
        fade_on_empty = false
        fade_timeout = 1000
        placeholder_text = <i><span foreground="##${toRgb colors.colors.subtext0}">🔒 Password...</span></i>
        hide_input = false
        rounding = 12
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

    # Color scheme file
    home.file.".config/hypr/colors".text = ''
      $background = rgba(1d192bee)
      $foreground = rgba(c3dde7ee)

      $color0 = rgba(1d192bee)
      $color1 = rgba(465EA7ee)
      $color2 = rgba(5A89B6ee)
      $color3 = rgba(6296CAee)
      $color4 = rgba(73B3D4ee)
      $color5 = rgba(7BC7DDee)
      $color6 = rgba(9CB4E3ee)
      $color7 = rgba(c3dde7ee)
      $color8 = rgba(889aa1ee)
      $color9 = rgba(465EA7ee)
      $color10 = rgba(5A89B6ee)
      $color11 = rgba(6296CAee)
      $color12 = rgba(73B3D4ee)
      $color13 = rgba(7BC7DDee)
      $color14 = rgba(9CB4E3ee)
      $color15 = rgba(c3dde7ee)
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
        border-radius: 12px;
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
        border-radius: 12px;
        margin: 10px;
        padding: 10px;
      }

      /* app grid */
      #apps-grid button {
        background-color: transparent;
        border-radius: 12px;
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
        border-radius: 16px;
        border: 2px solid ${rgba colors.colors.accent 0.3};
        padding: 4px;
      }

      #box {
        padding: 4px;
      }

      button {
        background: transparent;
        border-radius: 12px;
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
