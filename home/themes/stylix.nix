{ config, pkgs, lib, vars, colors, ... }:

let
  # When a curated Gallery theme is active, its GTK theme is selected explicitly
  # in home/themes/default.nix, so the Stylix HM GTK target must yield to avoid
  # a conflicting gtk.theme definition. Builtin themes keep Stylix GTK enabled.
  galleryActive = colors.galleryActive;
in
{
  # Stylix - System-wide automatic theming
  # Theme selection is based on vars.theme in vars.nix

  stylix = {
    enable = true;

    # Use theme-specific Base16 color scheme
    base16Scheme = colors.base16;

    # Polarity (dark/light/either)
    polarity = "dark";

    # Wallpaper (required by Stylix)
    # Generate a solid color wallpaper matching the theme
    image = pkgs.runCommand "stylix-wallpaper.png" {
      buildInputs = [ pkgs.imagemagick ];
    } ''
      magick -size 1920x1080 xc:'#${colors.base16.base00}' $out
    '';

    # Cursor theme
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    # Font configuration
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 12;
        desktop = 12;
        popups = 11;
        terminal = 12;
      };
    };

    # Opacity settings (0.0 - 1.0)
    opacity = {
      applications = 0.95;
      desktop = 0.9;
      popups = 0.95;
      terminal = 0.85;
    };

    # Target-specific settings
    targets = {
      # GTK theming
      gtk.enable = true;

      # GNOME/GSettings
      gnome.enable = true;

      # Console (virtual terminal)
      console.enable = true;

      # GRUB bootloader
      grub.enable = false;
    };
  };

  # Home-manager Stylix targets
  home-manager.users.${vars.username} = {
    stylix.targets = {
      # Terminal emulators
      kitty.enable = false;  # We have custom kitty config with colors

      # Wayland compositors
      hyprland.enable = false;  # We have custom hyprland config

      # Application launchers
      rofi.enable = false;  # We have custom rofi theme

      # Notification daemons
      dunst.enable = false;  # We use swaync
      swaync.enable = true;

      # Bars
      waybar.enable = false;  # We have custom waybar with theme colors

      # Editors
      vscode.enable = false;  # We have custom vscode config
      vim.enable = true;
      neovim.enable = true;

      # Browsers
      firefox.enable = true;

      # File managers
      xfce.enable = false;  # Thunar - disabled due to xfconf issues

      # Git tools
      lazygit.enable = true;

      # System monitors
      btop.enable = true;

      # Other
      fzf.enable = true;
      bat.enable = true;
      spicetify.enable = false;  # We have custom spicetify theme

      # GTK (disabled for Gallery themes: gtk.theme is set explicitly there)
      gtk.enable = !galleryActive;

      # Qt
      qt.enable = true;
    };
  };
}
