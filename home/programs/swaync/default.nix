{ config, lib, pkgs, vars, colors, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;
in
{
  home-manager.users.${vars.username} = {
    services.swaync = {
      enable = true;

      settings = {
        positionX = "right";
        positionY = "top";
        layer = "overlay";
        control-center-layer = "top";
        layer-shell = true;
        cssPriority = "application";

        control-center-margin-top = 10;
        control-center-margin-bottom = 10;
        control-center-margin-right = 10;
        control-center-margin-left = 10;

        notification-2fa-action = true;
        notification-inline-replies = false;
        notification-icon-size = 64;
        notification-body-image-height = 100;
        notification-body-image-width = 200;

        timeout = 10;
        timeout-low = 5;
        timeout-critical = 0;

        fit-to-screen = true;

        control-center-width = 380;
        control-center-height = 600;
        notification-window-width = 350;

        keyboard-shortcuts = true;
        image-visibility = "when-available";
        transition-time = 200;
        hide-on-clear = false;
        hide-on-action = true;
        script-fail-notify = true;

        widgets = [
          "inhibitors"
          "title"
          "dnd"
          "notifications"
          "mpris"
          "volume"
          "backlight"
          "buttons-grid"
        ];

        widget-config = {
          inhibitors = {
            text = "Inhibitors";
            button-text = "Clear";
            clear-all-button = true;
          };
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "Clear All";
          };
          dnd = {
            text = "Do Not Disturb";
          };
          mpris = {
            image-size = 96;
            image-radius = 12;
          };
          volume = {
            label = "󰕾";
          };
          backlight = {
            label = "󰃟";
          };
          buttons-grid = {
            actions = [
              {
                label = "󰖩";
                command = "nm-connection-editor";
              }
              {
                label = "󰂯";
                command = "blueman-manager";
              }
              {
                label = "";
                command = "pavucontrol";
              }
              {
                label = "󰌾";
                command = "hyprlock";
              }
              {
                label = "󰐥";
                command = "wlogout";
              }
            ];
          };
        };
      };

      style = ''
        * {
          all: unset;
          font-family: "JetBrainsMono Nerd Font";
          font-size: 14px;
          transition: 200ms;
        }

        .notification-row {
          outline: none;
        }

        .notification-row:focus,
        .notification-row:hover {
          background: ${rgba c.accent 0.1};
        }

        .notification {
          border-radius: 14px;
          margin: 6px 12px;
          box-shadow: 0 0 5px 0 rgba(0, 0, 0, 0.5);
          padding: 0;
          background: ${rgba c.base 0.95};
          border: 2px solid ${rgba c.accent 0.3};
        }

        .notification-content {
          padding: 10px;
        }

        .close-button {
          background: ${rgba c.red 0.3};
          color: ${c.red};
          border-radius: 6px;
          padding: 4px;
          margin: 6px;
        }

        .close-button:hover {
          background: ${rgba c.red 0.5};
        }

        .notification-default-action,
        .notification-action {
          padding: 4px;
          margin: 0;
          border-radius: 8px;
        }

        .notification-default-action:hover,
        .notification-action:hover {
          background: ${rgba c.accent 0.15};
        }

        .notification-default-action {
          border-radius: 14px;
        }

        .summary {
          font-weight: bold;
          font-size: 14px;
          color: ${c.text};
        }

        .time {
          font-size: 12px;
          color: ${c.overlay0};
          margin-right: 10px;
        }

        .body {
          font-size: 13px;
          color: ${c.subtext1};
        }

        .body-image {
          margin-top: 8px;
          border-radius: 8px;
        }

        .critical {
          border: 2px solid ${rgba c.red 0.7};
        }

        .low {
          border: 2px solid ${rgba c.green 0.3};
        }

        /* Control Center */
        .control-center {
          background: ${rgba c.base 0.95};
          border-radius: 14px;
          border: 2px solid ${rgba c.accent 0.3};
          box-shadow: 0 0 15px 0 rgba(0, 0, 0, 0.6);
          margin: 10px;
          padding: 10px;
        }

        .control-center-list {
          background: transparent;
        }

        .control-center-list-placeholder {
          opacity: 0.5;
        }

        /* Widgets */
        .widget-title {
          color: ${c.text};
          font-size: 18px;
          font-weight: bold;
          margin: 10px;
        }

        .widget-title > button {
          font-size: 12px;
          color: ${c.red};
          background: ${rgba c.red 0.2};
          border-radius: 8px;
          padding: 4px 12px;
        }

        .widget-title > button:hover {
          background: ${rgba c.red 0.4};
        }

        .widget-dnd {
          background: ${rgba c.surface0 0.6};
          border-radius: 14px;
          margin: 6px 10px;
          padding: 6px 10px;
        }

        .widget-dnd > switch {
          background: ${rgba c.surface2 0.5};
          border-radius: 20px;
        }

        .widget-dnd > switch:checked {
          background: ${rgba c.accent 0.6};
        }

        .widget-dnd > switch slider {
          background: ${c.text};
          border-radius: 50%;
        }

        /* Buttons Grid */
        .widget-buttons-grid {
          background: ${rgba c.surface0 0.4};
          border-radius: 14px;
          margin: 6px 10px;
          padding: 10px;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button {
          background: ${rgba c.surface2 0.4};
          border-radius: 10px;
          padding: 10px;
          margin: 4px;
          min-width: 50px;
          min-height: 40px;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button:hover {
          background: ${rgba c.accent 0.3};
        }

        .widget-buttons-grid > flowbox > flowboxchild > button label {
          font-size: 18px;
          color: ${c.text};
        }

        /* MPRIS */
        .widget-mpris {
          background: ${rgba c.surface0 0.6};
          border-radius: 14px;
          margin: 6px 10px;
          padding: 10px;
        }

        .widget-mpris-player {
          padding: 6px;
        }

        .widget-mpris-title {
          font-weight: bold;
          font-size: 14px;
          color: ${c.text};
        }

        .widget-mpris-subtitle {
          font-size: 12px;
          color: ${c.subtext0};
        }

        .widget-mpris > box > button {
          background: ${rgba c.surface2 0.4};
          border-radius: 50%;
          padding: 8px;
          margin: 4px;
        }

        .widget-mpris > box > button:hover {
          background: ${rgba c.accent 0.3};
        }

        /* Volume/Backlight */
        .widget-volume,
        .widget-backlight {
          background: ${rgba c.surface0 0.6};
          border-radius: 14px;
          margin: 6px 10px;
          padding: 6px 10px;
        }

        .widget-volume > box > button,
        .widget-backlight > box > button {
          background: transparent;
          color: ${c.text};
        }

        trough {
          background: ${rgba c.surface2 0.5};
          border-radius: 20px;
          min-height: 8px;
        }

        highlight {
          background: linear-gradient(90deg, ${c.accent}, ${c.accentAlt});
          border-radius: 20px;
        }

        slider {
          background: ${c.text};
          border-radius: 50%;
          min-width: 16px;
          min-height: 16px;
          margin: -4px 0;
        }

        /* Inhibitors */
        .widget-inhibitors {
          background: ${rgba c.surface0 0.6};
          border-radius: 14px;
          margin: 6px 10px;
          padding: 6px 10px;
        }

        .widget-inhibitors > button {
          font-size: 12px;
          color: ${c.peach};
          background: ${rgba c.peach 0.2};
          border-radius: 8px;
          padding: 4px 12px;
        }

        .widget-inhibitors > button:hover {
          background: ${rgba c.peach 0.4};
        }

        /* Toggle button (top right) */
        .toggle-button {
          background: transparent;
        }
      '';
    };

    # Commands for SwayNC management
    home.packages = with pkgs; [
      swaynotificationcenter
    ];
  };
}
