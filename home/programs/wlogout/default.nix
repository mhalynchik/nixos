{ config, lib, pkgs, vars, colors, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;
in
{
  home-manager.users.${vars.username} = {
    programs.wlogout = {
      enable = true;
      
      layout = [
        {
          label = "lock";
          action = "hyprlock";
          text = "Lock";
          keybind = "l";
        }
        {
          label = "hibernate";
          action = "systemctl hibernate";
          text = "Hibernate";
          keybind = "h";
        }
        {
          label = "logout";
          action = "hyprctl dispatch exit";
          text = "Logout";
          keybind = "e";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutdown";
          keybind = "s";
        }
        {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "u";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot";
          keybind = "r";
        }
      ];

      style = ''
        * {
          background-image: none;
          font-family: "JetBrainsMono Nerd Font";
          font-size: 14px;
        }

        window {
          background-color: ${rgba c.base 0.85};
        }

        button {
          color: ${c.text};
          background-color: ${rgba c.surface0 0.8};
          border-style: solid;
          border-width: 2px;
          border-color: ${rgba c.accent 0.3};
          background-repeat: no-repeat;
          background-position: center;
          background-size: 25%;
          border-radius: 14px;
          margin: 10px;
          transition: all 0.3s ease;
        }

        button:hover {
          background-color: ${rgba c.surface1 0.9};
          border-color: ${rgba c.accent 0.8};
          outline-style: none;
        }

        button:focus {
          background-color: ${rgba c.surface1 0.9};
          border-color: ${c.accent};
          outline-style: none;
        }

        #lock {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
          color: ${c.green};
        }

        #lock:hover {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
          background-color: ${rgba c.green 0.2};
          border-color: ${c.green};
        }

        #logout {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
          color: ${c.yellow};
        }

        #logout:hover {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
          background-color: ${rgba c.yellow 0.2};
          border-color: ${c.yellow};
        }

        #suspend {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
          color: ${c.blue};
        }

        #suspend:hover {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
          background-color: ${rgba c.blue 0.2};
          border-color: ${c.blue};
        }

        #hibernate {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
          color: ${c.mauve};
        }

        #hibernate:hover {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
          background-color: ${rgba c.mauve 0.2};
          border-color: ${c.mauve};
        }

        #shutdown {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
          color: ${c.red};
        }

        #shutdown:hover {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
          background-color: ${rgba c.red 0.2};
          border-color: ${c.red};
        }

        #reboot {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
          color: ${c.peach};
        }

        #reboot:hover {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
          background-color: ${rgba c.peach 0.2};
          border-color: ${c.peach};
        }
      '';
    };
  };
}
