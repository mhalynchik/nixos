{ config, lib, pkgs, vars, colors, inputs, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;

  # Curated Gallery GTK/icon selection. For builtin themes galleryAssets is null
  # and the GTK block below is byte-for-byte identical to the previous config.
  gallery = import ./gallery { inherit lib inputs; };
  galleryActive = gallery.isGallery vars.theme;
  galleryAssets =
    if galleryActive then gallery.assetsFor { inherit pkgs; theme = vars.theme; } else null;
in
{
  imports = [
    ./cava
    ./fastfetch
    ./stylix.nix  # Stylix handles GTK, Qt, and system-wide theming
  ];

  home-manager.users.${vars.username} = lib.mkMerge [
  {
    # GTK icon theme (Stylix handles the rest for builtin themes). When a Gallery
    # theme is active, its GTK theme + icon theme (read-only store derivations)
    # are explicitly selected instead of Papirus/Stylix.
    gtk = {
      enable = true;
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
      iconTheme =
        if galleryActive then {
          name = galleryAssets.iconTheme.name;
          package = galleryAssets.iconTheme.package;
        } else {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
    } // lib.optionalAttrs galleryActive {
      theme = {
        name = galleryAssets.gtkTheme.name;
        package = galleryAssets.gtkTheme.package;
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };

    # Electron/Chromium apps: run natively on Wayland with server-side
    # decorations. Dark web content is driven by the xdg-desktop-portal
    # color-scheme (prefer-dark, set above); this file only fixes rendering.
    # App chrome that ships its own theme (Cursor, VSCode, Discord, Spotify)
    # is controlled inside each app, not here.
    home.file.".config/electron-flags.conf".text = ''
      --ozone-platform-hint=auto
      --enable-features=WaylandWindowDecorations
    '';

    # Thunar custom actions and settings
    home.file.".config/Thunar/uca.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <actions>
        <action>
          <icon>utilities-terminal</icon>
          <name>Open Terminal Here</name>
          <unique-id>1</unique-id>
          <command>kitty --working-directory %f</command>
          <description>Open a terminal in this directory</description>
          <patterns>*</patterns>
          <startup-notify/>
          <directories/>
        </action>
        <action>
          <icon>edit-find</icon>
          <name>Search Files</name>
          <unique-id>2</unique-id>
          <command>catfish --path=%f</command>
          <description>Search for files</description>
          <patterns>*</patterns>
          <directories/>
        </action>
      </actions>
    '';

    # networkmanager_dmenu config (dark theme matching rofi)
    home.file.".config/networkmanager-dmenu/config.ini".text = ''
      [dmenu]
      dmenu_command = rofi -dmenu -i -p "Network"
      rofi_highlight = True
      wifi_chars = ▂▄▆█

      [editor]
      terminal = kitty
      gui_if_available = False
    '';

    # Custom rofi theme for games (uses same colors as main rofi with 60% transparency)
    home.file.".config/rofi/games.rasi".text = ''
      /*****----- Rofi Games Theme -----*****/
      /* Theme: ${colors.displayName} with 60% transparency */
      * {
          font:                        "${colors.fonts.monospace} 11";
          background:                  ${rgba c.base 0.6};
          background-alt:              ${rgba c.surface0 0.7};
          foreground:                  ${c.text};
          selected:                    ${c.accent};
          active:                      ${c.accentAlt};
          urgent:                      ${c.red};
          border-color:                ${c.accent};
      }

      window {
          transparency:                "real";
          location:                    center;
          anchor:                      center;
          width:                       700px;
          border-radius:               14px;
          border:                      2px solid;
          border-color:                @selected;
          background-color:            ${rgba c.base 0.6};
      }

      mainbox {
          enabled:                     true;
          spacing:                     15px;
          padding:                     20px;
          background-color:            transparent;
          orientation:                 vertical;
          children:                    [ "inputbar", "message", "listview" ];
      }

      inputbar {
          spacing:                     10px;
          padding:                     12px 16px;
          border-radius:               14px;
          background-color:            @background-alt;
          text-color:                  @foreground;
          children:                    [ "textbox-prompt-colon", "entry" ];
      }

      textbox-prompt-colon {
          expand:                      false;
          str:                         "🎮";
          background-color:            inherit;
          text-color:                  @selected;
      }

      entry {
          background-color:            inherit;
          text-color:                  inherit;
          placeholder:                 "Search games...";
          placeholder-color:           ${c.overlay0};
      }

      listview {
          columns:                     1;
          lines:                       10;
          spacing:                     5px;
          scrollbar:                   false;
          background-color:            transparent;
      }

      element {
          spacing:                     15px;
          padding:                     10px 15px;
          border-radius:               14px;
          background-color:            transparent;
          text-color:                  @foreground;
      }

      element selected {
          background-color:            @selected;
          text-color:                  ${c.crust};
      }

      element-icon {
          size:                        48px;
          background-color:            transparent;
      }

      element-text {
          background-color:            transparent;
          text-color:                  inherit;
          vertical-align:              0.5;
      }
    '';

    # Xfce settings for Thunar dark theme
    home.file.".config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="thunar" version="1.0">
        <property name="last-view" type="string" value="ThunarIconView"/>
        <property name="last-icon-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_100_PERCENT"/>
        <property name="last-details-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_50_PERCENT"/>
        <property name="last-window-width" type="int" value="1000"/>
        <property name="last-window-height" type="int" value="600"/>
        <property name="last-window-maximized" type="bool" value="false"/>
        <property name="misc-single-click" type="bool" value="false"/>
        <property name="misc-show-delete-action" type="bool" value="true"/>
        <property name="misc-thumbnail-mode" type="string" value="THUNAR_THUMBNAIL_MODE_ALWAYS"/>
        <property name="misc-file-size-binary" type="bool" value="true"/>
        <property name="shortcuts-icon-size" type="string" value="THUNAR_ICON_SIZE_24"/>
        <property name="tree-icon-size" type="string" value="THUNAR_ICON_SIZE_16"/>
      </channel>
    '';

  }

  (lib.mkIf galleryActive {
    # Expose the curated Gallery GTK/icon derivations through the user data dirs
    # so Flatpak apps (granted xdg-data/themes|icons in flatpak.nix) can discover
    # them. These are symlinks to the read-only store, never extracted into $HOME.
    home.file.".local/share/themes/${galleryAssets.gtkTheme.name}".source =
      "${galleryAssets.gtkTheme.package}/share/themes/${galleryAssets.gtkTheme.name}";
    home.file.".local/share/icons/${galleryAssets.iconTheme.name}".source =
      "${galleryAssets.iconTheme.package}/share/icons/${galleryAssets.iconTheme.name}";
  })
  ];
}
