{ config, pkgs, vars, colors, ... }:

let
  rgba = colors.toRgba;
  c = colors.colors;
in
{
  home-manager.users.${vars.username} = {
    services.swayosd = {
      enable = true;
      stylePath = pkgs.writeText "swayosd.css" ''
        window {
          background-color: ${c.base};
          border-radius: 14px;
          border: 2px solid ${rgba c.accent 0.3};
          padding: 16px;
        }
        label {
          color: ${c.text};
          font-size: 14px;
        }
        image {
          color: ${c.accent};
        }
        progressbar {
          background-color: ${c.surface0};
          border-radius: 8px;
        }
        progressbar progress {
          background-color: ${c.accent};
          border-radius: 8px;
        }
      '';
    };

    home.packages = [ pkgs.swayosd ];
  };
}
