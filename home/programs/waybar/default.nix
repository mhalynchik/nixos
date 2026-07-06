{ config, lib, pkgs, vars, colors, ... }:

let
  wb = colors.waybar;
  rgba = colors.toRgba;

  # Audio visualizer script
  audio-visualizer = pkgs.writeShellScriptBin "audio-visualizer" ''
    #!/usr/bin/env bash

    config_file="/tmp/cava_waybar_config"

    cat > "$config_file" << 'EOF'
    [general]
    bars = 12
    framerate = 60
    sensitivity = 100

    [input]
    method = pipewire
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 7
    EOF

    chars=(' ' '▂' '▃' '▄' '▅' '▆' '▇' '█')

    ${pkgs.cava}/bin/cava -p "$config_file" 2>/dev/null | while IFS=';' read -r -a values; do
      output=""
      for value in "''${values[@]}"; do
        if [ -n "$value" ] && [ "$value" -ge 0 ] 2>/dev/null; then
          idx=$((value > 7 ? 7 : value))
          output+="''${chars[$idx]}"
        fi
      done
      echo "$output"
    done
  '';
in
{
  home-manager.users.${vars.username} = {
    home.packages = [ audio-visualizer ];

    programs.waybar = {
      enable = true;
      systemd = {
        enable = false;
        target = "graphical-session.target";
      };
      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 12pt;
          font-weight: bold;
          border-radius: 8px;
          transition-property: background-color;
          transition-duration: 0.5s;
        }

        @keyframes blink_red {
          to {
            background-color: ${colors.colors.error};
            color: ${colors.colors.base};
          }
        }

        .warning, .critical, .urgent {
          animation-name: blink_red;
          animation-duration: 1s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
        }

        window#waybar { background-color: transparent; }

        window > box {
          margin-left: 5px;
          margin-right: 5px;
          margin-top: 5px;
          background-color: ${rgba colors.colors.base 0.65};
          padding: 3px;
          padding-left: 8px;
          border: 2px solid ${rgba colors.colors.accent 0.3};
          border-radius: 12px;
        }

        #workspaces { padding-left: 0px; padding-right: 4px; }

        #workspaces button {
          padding-top: 5px;
          padding-bottom: 5px;
          padding-left: 6px;
          padding-right: 6px;
          margin-right: 4px;
          border-radius: 8px;
          color: ${colors.colors.accent};
          background-color: transparent;
          font-weight: bold;
        }

        #workspaces button.active {
          background-color: ${rgba colors.colors.accent 0.2};
          color: ${colors.colors.accentAlt};
          border-bottom: 2px solid ${colors.colors.accentAlt};
          border-radius: 8px 8px 4px 4px;
        }

        #workspaces button.urgent {
          background-color: ${rgba colors.colors.error 0.3};
          color: ${colors.colors.error};
          animation: blink_red 0.5s ease infinite alternate;
        }

        #workspaces button:hover {
          background-color: ${rgba colors.colors.accent 0.25};
          color: ${colors.colors.text};
        }

        tooltip {
          background: ${colors.colors.surface1};
          border: 1px solid ${rgba colors.colors.accent 0.5};
          border-radius: 8px;
        }

        tooltip label { color: ${colors.colors.text}; }

        #custom-launcher {
          font-size: 20px;
          padding-left: 8px;
          padding-right: 6px;
          color: ${wb.launcher};
        }

        #custom-launcher:hover { color: ${colors.colors.accent}; }

        #clock {
          color: ${wb.clock};
          padding-left: 10px;
          padding-right: 10px;
        }

        #clock:hover { background-color: ${rgba colors.colors.accent 0.15}; }

        #custom-stats {
          color: ${wb.stats};
          padding-left: 10px;
          padding-right: 10px;
        }

        #custom-stats:hover { background-color: ${rgba colors.colors.accent 0.15}; }

        #pulseaudio {
          color: ${wb.audio};
          padding-left: 10px;
          padding-right: 10px;
        }

        #pulseaudio:hover { background-color: ${rgba colors.colors.accent 0.15}; }
        #pulseaudio.muted { color: ${colors.colors.overlay0}; }

        #custom-bluetooth {
          color: ${wb.bluetooth};
          padding-left: 10px;
          padding-right: 10px;
        }

        #custom-bluetooth:hover { background-color: ${rgba colors.colors.accent 0.15}; }

        #custom-network {
          color: ${wb.network};
          padding-left: 10px;
          padding-right: 10px;
        }

        #custom-network:hover { background-color: ${rgba colors.colors.accent 0.15}; }

        #custom-keyboard {
          color: ${wb.keyboard};
          padding-left: 10px;
          padding-right: 10px;
        }

        #custom-keyboard:hover { background-color: ${rgba colors.colors.accent 0.15}; }

        #battery {
          color: ${wb.battery};
          padding-left: 10px;
          padding-right: 10px;
        }

        #battery.charging { color: ${wb.batteryCharging}; }
        #battery.warning:not(.charging) { color: ${wb.batteryWarning}; }
        #battery.critical:not(.charging) { color: ${wb.batteryCritical}; }

        #custom-powermenu {
          color: ${wb.powerMenu};
          padding-left: 10px;
          padding-right: 8px;
        }

        #custom-powermenu:hover {
          color: ${colors.colors.error};
          background-color: ${rgba colors.colors.error 0.15};
        }

        #tray {
          padding-right: 8px;
          padding-left: 10px;
        }

        #tray > .passive { -gtk-icon-effect: dim; }
        #tray > .needs-attention { -gtk-icon-effect: highlight; }

        #idle_inhibitor {
          color: ${colors.colors.mauve};
          padding-left: 10px;
          padding-right: 10px;
        }

        #idle_inhibitor.activated { color: ${colors.colors.warning}; }

        #custom-visualizer {
          color: ${wb.visualizer};
          font-family: "monospace";
          font-size: 10pt;
          padding-left: 6px;
          padding-right: 6px;
          min-width: 60px;
        }
      '';

      settings = [{
        layer = "top";
        position = "top";
        height = 35;
        spacing = 4;

        # Multi-monitor: show bar on all monitors
        # Each monitor gets its own waybar instance
        # Workspaces module shows only workspaces on current monitor
        "hyprland/workspaces" = {
          all-outputs = false;  # Show only workspaces from current monitor
          format = "{icon}";
          format-icons = {
            "1" = "󰲠";
            "2" = "󰲢";
            "3" = "󰲤";
            "4" = "󰲦";
            "5" = "󰲨";
            "6" = "󰲪";
            "7" = "󰲬";
            "8" = "󰲮";
            "9" = "󰲰";
            "10" = "󰿬";
            urgent = "";
            active = "";
            default = "";
          };
          on-click = "activate";
          sort-by-number = true;
        };

        "hyprland/window" = {
          format = "{}";
          max-length = 40;
          separate-outputs = true;
        };

        modules-left = [
          "custom/launcher"
          "hyprland/workspaces"
          "hyprland/window"
          "custom/visualizer"
        ];

        modules-center = [
          "clock"
        ];

        modules-right = [
          "idle_inhibitor"
          "custom/stats"
          "pulseaudio"
          "custom/bluetooth"
          "custom/network"
          "custom/keyboard"
          "battery"
          "custom/powermenu"
          # "tray"
        ];

        "custom/launcher" = {
          format = "󰀻";
          on-click = "rofi -show drun -show-icons";
          on-click-right = "rofi -show run";
          tooltip = true;
          tooltip-format = "Apps Menu";
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰾪";
          };
          tooltip-format-activated = "Idle inhibitor: ON";
          tooltip-format-deactivated = "Idle inhibitor: OFF";
        };

        # System stats - opens AGS popup
        "custom/stats" = {
          format = "󰍛";
          on-click = "ags -t system-stats-popup";
          tooltip = true;
          tooltip-format = "System Monitor";
        };

        # Volume - opens AGS audio popup
        "pulseaudio" = {
          scroll-step = 5;
          format = "{icon}";
          format-muted = "󰖁";
          format-icons = {
            headphone = "󰋋";
            hands-free = "󰋎";
            headset = "󰋎";
            phone = "";
            portable = "";
            car = "";
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = "ags -t audio-popup";
          on-click-right = "pamixer -t";
          on-scroll-up = "pamixer -i 5";
          on-scroll-down = "pamixer -d 5";
          tooltip = true;
          tooltip-format = "{desc}: {volume}%";
        };

        # Bluetooth - opens AGS popup
        "custom/bluetooth" = {
          format = "󰂯";
          on-click = "ags -t bluetooth-popup";
          tooltip = true;
          tooltip-format = "Bluetooth";
        };

        # Network - opens AGS popup (replaced native network module)
        "custom/network" = {
          format = "󰖩";
          on-click = "ags -t network-popup";
          tooltip = true;
          tooltip-format = "Network";
        };

        # Keyboard layout - opens AGS popup
        "custom/keyboard" = {
          format = "{}";
          exec = "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -1 | sed 's/.*Russian.*/RU/; s/.*English.*/EN/'";
          interval = 1;
          on-click = "ags -t keyboard-popup";
          on-click-right = "hyprctl switchxkblayout all next";
          tooltip = true;
          tooltip-format = "Keyboard Layout\nClick: menu\nRight-click: switch";
        };

        # Clock - opens AGS calendar popup
        "clock" = {
          interval = 1;
          format = "󰥔 {:%H:%M}";
          format-alt = "󰃭 {:%d.%m.%Y}";
          on-click = "ags -t calendar-popup";
          tooltip = true;
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "battery" = {
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{icon}";
          format-charging = "󰂄";
          format-plugged = "󰂄";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip = true;
          tooltip-format = "{capacity}% - {timeTo}";
        };

        "custom/powermenu" = {
          format = "⏻";
          on-click = "wlogout";
          tooltip = true;
          tooltip-format = "Power Menu";
        };

        "tray" = {
          icon-size = 16;
          spacing = 8;
        };

        "custom/visualizer" = {
          format = "{}";
          exec = "audio-visualizer";
          tooltip = false;
          restart-interval = 5;
        };
      }];
    };
  };
}
