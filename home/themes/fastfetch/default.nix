{ config, pkgs, vars, colors, ... }:

{
  home-manager.users.${vars.username} = {
    # Fastfetch configuration
    home.file.".config/fastfetch/config.jsonc".text = ''
      {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "logo": {
          "type": "kitty-direct",
          "source": "nixos",
          "padding": {
            "top": 1,
            "left": 2,
            "right": 3
          }
        },
        "display": {
          "separator": "  ",
          "color": {
            "keys": "cyan",
            "title": "blue"
          }
        },
        "modules": [
          {
            "type": "title",
            "key": " "
          },
          {
            "type": "separator",
            "string": "─────────────────────────────────"
          },
          {
            "type": "os",
            "key": "  OS"
          },
          {
            "type": "kernel",
            "key": "  Kernel"
          },
          {
            "type": "packages",
            "key": "  Packages"
          },
          {
            "type": "wm",
            "key": "  WM"
          },
          {
            "type": "terminal",
            "key": "  Terminal"
          },
          {
            "type": "shell",
            "key": "  Shell"
          },
          {
            "type": "separator",
            "string": "─────────────────────────────────"
          },
          {
            "type": "cpu",
            "key": " 󰻠 CPU"
          },
          {
            "type": "gpu",
            "key": " 󰢮 GPU"
          },
          {
            "type": "memory",
            "key": "  Memory"
          },
          {
            "type": "disk",
            "key": " 󰋊 Disk (/)",
            "folders": "/"
          },
          {
            "type": "separator",
            "string": "─────────────────────────────────"
          },
          {
            "type": "display",
            "key": " 󰍹 Display"
          },
          {
            "type": "uptime",
            "key": "  Uptime"
          },
          {
            "type": "localip",
            "key": " 󰖩 Local IP",
            "showIpv4": true,
            "showIpv6": false
          },
          {
            "type": "separator",
            "string": "─────────────────────────────────"
          },
          {
            "type": "colors",
            "paddingLeft": 2,
            "symbol": "circle"
          }
        ]
      }
    '';
  };
}
