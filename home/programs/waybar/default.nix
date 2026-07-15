{ config, lib, pkgs, vars, colors, ... }:

let
  wb = colors.waybar;
  rgba = colors.toRgba;
  c = colors.colors;

  agsClick = cmd: if vars.programs.ags then cmd else null;
  optionalClick = cmd: lib.optionalAttrs (cmd != null) { on-click = cmd; };

  audioClick = if vars.programs.ags then "ags -t audio-popup" else "pavucontrol";
  btClick = if vars.programs.ags then "ags -t bluetooth-popup" else "blueman-manager";
  netClick = if vars.programs.ags then "ags -t network-popup" else "nm-connection-editor";
  # With AGS the click opens the stats popup; without it fall back to btop in a
  # terminal so the module stays useful instead of being a dead button.
  statsClick = if vars.programs.ags then "ags -t system-stats-popup" else "${vars.terminal} -e btop";
  clockClick = agsClick "ags -t calendar-popup";
  langClick = if vars.programs.ags then "ags -t keyboard-popup" else "hyprctl switchxkblayout all next";

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
    home.packages = [ audio-visualizer ] ++ lib.optional (!vars.programs.ags) pkgs.btop;

    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        target = "graphical-session.target";
      };

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 0;
        }

        window#waybar {
          background: transparent;
        }

        #left, #center, #right {
          background-color: ${rgba c.base 0.7};
          border-radius: 14px;
          border: 1px solid ${rgba c.accent 0.3};
          padding: 4px 10px;
          margin: 2px 6px;
        }

        #workspaces button {
          margin: 2px;
          padding: 0 12px;
          border-radius: 10px;
          font-size: 18px;
          color: ${c.subtext0};
          background-color: transparent;
          transition: all 0.15s ease-out;
        }

        #workspaces button.active {
          background: ${wb.workspaceActive};
          color: ${c.crust};
        }

        #workspaces button.urgent {
          background: ${wb.workspaceUrgent};
        }

        #workspaces button:hover:not(.active) {
          background: ${wb.workspaceHover};
        }

        #window {
          color: ${c.text};
          padding: 0 8px;
        }

        tooltip {
          background: ${c.surface1};
          border: 1px solid ${rgba c.accent 0.3};
          border-radius: 14px;
        }

        tooltip label { color: ${c.text}; }

        #custom-launcher { color: ${wb.launcher}; font-size: 16px; padding: 0 6px; }
        #clock { color: ${wb.clock}; padding: 0 8px; }
        #custom-stats { color: ${wb.stats}; padding: 0 8px; }
        #pulseaudio { color: ${wb.audio}; padding: 0 8px; }
        #pulseaudio.muted { color: ${c.overlay0}; }
        #bluetooth { color: ${wb.bluetooth}; padding: 0 8px; }
        #bluetooth.off, #bluetooth.disabled { color: ${c.overlay0}; }
        #network { color: ${wb.network}; padding: 0 8px; }
        #network.disconnected { color: ${c.overlay0}; }
        #language { color: ${wb.keyboard}; padding: 0 8px; }
        #battery { color: ${wb.battery}; padding: 0 8px; }
        #battery.charging { color: ${wb.batteryCharging}; }
        #battery.warning:not(.charging) { color: ${wb.batteryWarning}; }
        #battery.critical:not(.charging) { color: ${wb.batteryCritical}; }
        #custom-powermenu { color: ${wb.powerMenu}; padding: 0 8px; }
        #idle_inhibitor { color: ${c.mauve}; padding: 0 8px; }
        #idle_inhibitor.activated { color: ${c.warning}; }
        #custom-visualizer { color: ${wb.visualizer}; font-size: 10px; min-width: 48px; }
        #tray { padding: 0 6px; }
        #custom-gamemode { padding: 0 8px; }
        #custom-gamemode.on { color: ${c.red}; }
        #custom-gamemode.off { color: ${c.subtext0}; }
      '';

      settings = [{
        layer = "top";
        position = "top";
        height = 40;
        spacing = 0;

        "hyprland/workspaces" = {
          all-outputs = false;
          format = "{name}";
          format-icons = {
            urgent = "!"; active = ""; default = "";
          };
          on-click = "activate";
          sort-by-number = true;
        };

        "hyprland/window" = {
          format = "{}";
          max-length = 35;
          separate-outputs = true;
        };

        "hyprland/language" = {
          format = "{}";
          format-en = "EN";
          format-ru = "RU";
          on-click = langClick;
          on-click-right = "hyprctl switchxkblayout all next";
          tooltip-format = "Keyboard\nClick: menu/switch\nRight-click: switch";
        };

        modules-left = [ "group/left" ];
        modules-center = [ "group/center" ];
        modules-right = [ "group/right" ];

        "group/left" = {
          orientation = "inherit";
          modules = [
            "custom/launcher"
            "hyprland/workspaces"
            "hyprland/window"
            "custom/visualizer"
          ];
        };

        "group/center" = {
          orientation = "inherit";
          modules = [ "clock" ];
        };

        "group/right" = {
          orientation = "inherit";
          modules = lib.flatten [
            [ "idle_inhibitor" "custom/stats" "pulseaudio" "bluetooth" "network" "hyprland/language" ]
            (lib.optional vars.features.gaming "custom/gamemode")
            [ "battery" "tray" "custom/powermenu" ]
          ];
        };

        "custom/launcher" = {
          format = "󰀻";
          on-click = "rofi -show drun -show-icons";
          on-click-right = "rofi -show run";
          tooltip = true;
          tooltip-format = "Apps Menu";
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = { activated = "󰅶"; deactivated = "󰾪"; };
          tooltip-format-activated = "Idle inhibitor: ON";
          tooltip-format-deactivated = "Idle inhibitor: OFF";
        };

        "custom/stats" = {
          format = "󰍛";
          tooltip = true;
          tooltip-format = "System Monitor";
        } // optionalClick statsClick;

        "pulseaudio" = {
          scroll-step = 5;
          format = "{icon}";
          format-muted = "󰖁";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
            headphone = "󰋋";
            hands-free = "󰋎";
            headset = "󰋎";
          };
          on-click = audioClick;
          on-click-right = "swayosd-client --output-volume mute-toggle";
          on-scroll-up = "swayosd-client --output-volume raise";
          on-scroll-down = "swayosd-client --output-volume lower";
          tooltip = true;
          tooltip-format = "{desc}: {volume}%";
        };

        # Native module: reflects the real adapter/connection state.
        "bluetooth" = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-off = "󰂲";
          format-on = "󰂯";
          format-connected = "󰂱 {num_connections}";
          on-click = btClick;
          tooltip = true;
          tooltip-format = "{controller_alias}\n{status}";
          tooltip-format-connected = "{controller_alias}\n{num_connections} connected\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
        };

        # Native module: reflects the real network state.
        "network" = {
          format-wifi = "󰤨";
          format-ethernet = "󰈀";
          format-linked = "󰈀";
          format-disconnected = "󰤮";
          on-click = netClick;
          tooltip = true;
          tooltip-format = "{ifname} {ipaddr}";
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}";
          tooltip-format-disconnected = "Disconnected";
        };

        "clock" = {
          interval = 1;
          format = "󰥔 {:%H:%M}";
          format-alt = "󰃭 {:%d.%m.%Y}";
          tooltip = true;
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        } // optionalClick clockClick;

        "battery" = {
          states = { good = 95; warning = 30; critical = 15; };
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

        "custom/gamemode" = lib.mkIf vars.features.gaming {
          format = "{icon}";
          exec = "gaming-mode status";
          interval = 5;
          signal = 8;
          format-icons = {
            on = "󰊛";
            off = "󰊝";
          };
          on-click = "gaming-mode toggle";
          tooltip = true;
          tooltip-format = "Gaming profile";
        };
      }];
    };
  };
}
