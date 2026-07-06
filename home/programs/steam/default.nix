{ config, pkgs, lib, vars, colors, ... }:

{
  home-manager.users.${vars.username} = {
    # Steam skin/theme configuration
    # IMPORTANT: We use home.activation instead of home.file for Steam paths
    # because home.file creates ~/.steam/steam/ as a real directory,
    # but Steam expects to create ~/.steam/steam as a SYMLINK to ~/.local/share/Steam/
    # Pre-creating it as a directory causes "Couldn't set up Steam data" error on first launch

    # Apply Steam theme via activation script (only if Steam is already set up)
    home.activation.applySteamTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      STEAM_DATA="$HOME/.local/share/Steam"

      # Only apply theme if Steam has been launched at least once
      if [ -d "$STEAM_DATA" ]; then
        # Catppuccin Mocha skin
        SKIN_DIR="$STEAM_DATA/skins/Catppuccin-Mocha/resource/styles"
        mkdir -p "$SKIN_DIR"
        cat > "$SKIN_DIR/steam.styles" << 'SKINEOF'
      /* Steam Catppuccin Mocha Dark Theme */
      /* Custom CSS-like styling for Steam */

      "Steam" {
        colors {
          /* Base colors */
          base_background = "${colors.colors.base}"
          secondary_background = "${colors.colors.mantle}"
          tertiary_background = "${colors.colors.crust}"

          /* Text colors */
          base_text = "${colors.colors.text}"
          secondary_text = "${colors.colors.subtext0}"
          muted_text = "${colors.colors.overlay0}"

          /* Accent colors */
          accent = "${colors.colors.accent}"
          accent_hover = "${colors.colors.sapphire}"
          focus = "${colors.colors.lavender}"

          /* Status colors */
          online = "${colors.colors.green}"
          away = "${colors.colors.yellow}"
          busy = "${colors.colors.red}"
          offline = "${colors.colors.overlay0}"

          /* Button colors */
          button_bg = "${colors.colors.surface0}"
          button_hover = "${colors.colors.surface1}"
          button_active = "${colors.colors.surface2}"
        }
      }
SKINEOF

        # Steam library CSS (for new UI)
        CSS_DIR="$STEAM_DATA/steamui/css"
        mkdir -p "$CSS_DIR"
        cat > "$CSS_DIR/custom.css" << 'CSSEOF'
      /* Steam Library Catppuccin Mocha Theme */
      /* For the new Steam Library UI */

      :root {
        /* Override Steam's CSS variables */
        --gpColor-Store-Darkest: ${colors.colors.crust} !important;
        --gpColor-Store-Darker: ${colors.colors.mantle} !important;
        --gpColor-Store-Dark: ${colors.colors.base} !important;
        --gpColor-Store-Mid: ${colors.colors.surface0} !important;
        --gpColor-Store-Light: ${colors.colors.surface1} !important;
        --gpColor-Store-Lighter: ${colors.colors.surface2} !important;
        --gpColor-Store-Lightest: ${colors.colors.overlay0} !important;

        --gpColor-Grey80: ${colors.colors.text} !important;
        --gpColor-Grey70: ${colors.colors.subtext1} !important;
        --gpColor-Grey60: ${colors.colors.subtext0} !important;
        --gpColor-Grey50: ${colors.colors.overlay2} !important;
        --gpColor-Grey40: ${colors.colors.overlay1} !important;
        --gpColor-Grey30: ${colors.colors.overlay0} !important;
        --gpColor-Grey20: ${colors.colors.surface2} !important;
        --gpColor-Grey10: ${colors.colors.surface1} !important;
        --gpColor-Grey05: ${colors.colors.surface0} !important;

        --gpColor-Green-Std: ${colors.colors.green} !important;
        --gpColor-Blue-Std: ${colors.colors.blue} !important;
        --gpColor-Red-Std: ${colors.colors.red} !important;
        --gpColor-Yellow-Std: ${colors.colors.yellow} !important;

        /* Accent color */
        --gpColor-Blue-Dark: ${colors.colors.accent} !important;
        --gpColor-Blue-Mid: ${colors.colors.sapphire} !important;
        --gpColor-Blue-Light: ${colors.colors.sky} !important;
      }

      /* Main window background */
      .main_LibraryBg_3hWRm,
      .library_AppDetailsMainBackground_3Kz9B,
      .libraryhome_Container_1Vg6E {
        background: ${colors.colors.base} !important;
      }

      /* Sidebar */
      .gamelistbar_GameListBar_1ald1,
      .gamelistbar_Container_1X7NH {
        background: ${colors.colors.mantle} !important;
      }

      /* Header */
      .libraryHeader_LibraryHeader_2zrgH {
        background: ${colors.colors.crust} !important;
      }

      /* Game list items */
      .gamelistentry_GameListEntry_15pLP {
        background: transparent !important;
      }

      .gamelistentry_GameListEntry_15pLP:hover {
        background: ${colors.colors.surface0} !important;
      }

      .gamelistentry_GameListEntry_15pLP.gamelistentry_Active_2FbTn {
        background: ${colors.colors.surface1} !important;
      }

      /* Text colors */
      .gamelistentry_GameTitle_3gk_E,
      .appdetails_Title_2bJeJ {
        color: ${colors.colors.text} !important;
      }

      /* Buttons */
      .DialogButton {
        background: ${colors.colors.surface0} !important;
        color: ${colors.colors.text} !important;
        border: 1px solid ${colors.colors.surface1} !important;
      }

      .DialogButton:hover {
        background: ${colors.colors.surface1} !important;
      }

      .DialogButton.Primary {
        background: ${colors.colors.accent} !important;
        color: ${colors.colors.crust} !important;
      }

      .DialogButton.Primary:hover {
        background: ${colors.colors.sapphire} !important;
      }

      /* Input fields */
      .DialogInput,
      .DialogTextArea {
        background: ${colors.colors.surface0} !important;
        color: ${colors.colors.text} !important;
        border: 1px solid ${colors.colors.surface1} !important;
      }

      .DialogInput:focus,
      .DialogTextArea:focus {
        border-color: ${colors.colors.accent} !important;
      }

      /* Scrollbar */
      ::-webkit-scrollbar {
        width: 8px !important;
        height: 8px !important;
      }

      ::-webkit-scrollbar-track {
        background: ${colors.colors.base} !important;
      }

      ::-webkit-scrollbar-thumb {
        background: ${colors.colors.surface2} !important;
        border-radius: 4px !important;
      }

      ::-webkit-scrollbar-thumb:hover {
        background: ${colors.colors.overlay0} !important;
      }

      /* Selection */
      ::selection {
        background: ${colors.colors.surface2} !important;
        color: ${colors.colors.text} !important;
      }

      /* Dropdown menus */
      .contextmenu_ContextMenu_3Y3E2 {
        background: ${colors.colors.base} !important;
        border: 1px solid ${colors.colors.surface0} !important;
        border-radius: 8px !important;
      }

      .contextmenu_MenuItem_3Y3E2:hover {
        background: ${colors.colors.surface1} !important;
      }

      /* Modal dialogs */
      .DialogContent {
        background: ${colors.colors.base} !important;
        border: 1px solid ${colors.colors.surface0} !important;
        border-radius: 12px !important;
      }

      /* Friends list status */
      .friend_StatusOnline_2j6h4 {
        color: ${colors.colors.green} !important;
      }

      .friend_StatusAway_3EKsN {
        color: ${colors.colors.yellow} !important;
      }

      .friend_StatusBusy_1qkNh {
        color: ${colors.colors.red} !important;
      }

      .friend_StatusOffline_3Y2E2 {
        color: ${colors.colors.overlay0} !important;
      }

      /* Notifications */
      .Notification {
        background: ${colors.colors.base} !important;
        border-left: 4px solid ${colors.colors.accent} !important;
      }

      /* Achievement progress */
      .achievementProgress {
        background: ${colors.colors.surface0} !important;
      }

      .achievementProgress_Fill {
        background: ${colors.colors.green} !important;
      }

      /* Download progress */
      .downloadProgress {
        background: ${colors.colors.surface0} !important;
      }

      .downloadProgress_Fill {
        background: ${colors.colors.accent} !important;
      }
CSSEOF
        echo "Steam Catppuccin Mocha theme applied to $STEAM_DATA"
      else
        echo "Steam data directory not found at $STEAM_DATA — skipping theme (launch Steam first, then rebuild)"
      fi
    '';

    # Create a script to manually (re)apply Steam theme
    home.file.".local/bin/apply-steam-theme".source = pkgs.writeShellScript "apply-steam-theme" ''
      #!/usr/bin/env bash
      # Apply Catppuccin theme to Steam

      STEAM_DIR="$HOME/.local/share/Steam"

      if [ ! -d "$STEAM_DIR" ]; then
        echo "Error: Steam data directory not found at $STEAM_DIR"
        echo "Please launch Steam at least once before applying the theme."
        exit 1
      fi

      SKIN_DIR="$STEAM_DIR/skins/Catppuccin-Mocha"
      CSS_DIR="$STEAM_DIR/steamui/css"

      # Create directories if they don't exist
      mkdir -p "$SKIN_DIR/resource/styles"
      mkdir -p "$CSS_DIR"

      echo "Steam Catppuccin Mocha theme directories created!"
      echo "Run 'sudo nixos-rebuild switch' to apply theme files."
      echo "Then restart Steam for changes to take effect."
      echo "To use the skin, go to Steam Settings > Interface > Select skin"
    '';

    # Make the script executable
    home.file.".local/bin/apply-steam-theme".executable = true;

    # Steam launch options for dark mode (environment variable)
    home.sessionVariables = {
      # Force Steam to use system theme
      STEAM_FORCE_DESKTOPUI_SCALING = "1";
      # Исправление для запуска игр на Wayland
      # SDL должен использовать wayland с fallback на x11
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/${vars.username}/.steam/root/compatibilitytools.d";

      # Proton/Wine игры - принудительно использовать X11 через XWayland
      # Это критично для игр, которые не поддерживают Wayland напрямую
      PROTON_USE_WINED3D = "0";  # Использовать DXVK (Vulkan) вместо WineD3D
      PROTON_NO_ESYNC = "0";     # Включить esync для лучшей производительности
      PROTON_NO_FSYNC = "0";     # Включить fsync для лучшей производительности

      # Vulkan - выбор GPU (для систем с несколькими GPU)
      # Ваши RTX 5080 = device 0 и 1
      # VK_ICD_FILENAMES уже должен автоматически выбирать NVIDIA

      # Принудительно использовать X11 для Wine/Proton приложений
      WINE_FULLSCREEN_FSR = "1";  # AMD FSR upscaling (работает и на NVIDIA)
    };
  };
}
