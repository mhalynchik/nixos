{ config, lib, pkgs, vars, colors, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;
in
{
  imports = [
    ./cava
    ./fastfetch
    ./stylix.nix  # Stylix handles GTK, Qt, and system-wide theming
  ];

  home-manager.users.${vars.username} = {
    # GTK icon theme (Stylix handles the rest)
    gtk = {
      enable = true;
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

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
          border-radius:               12px;
          border:                      2px solid;
          border-color:                @selected;
          background-color:            ${rgba c.base 0.6};
      }

      mainbox {
          spacing:                     15px;
          padding:                     20px;
          background-color:            transparent;
      }

      inputbar {
          spacing:                     10px;
          padding:                     12px 16px;
          border-radius:               8px;
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
          border-radius:               8px;
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

  };
}
