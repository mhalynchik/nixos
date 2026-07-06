{ config, pkgs, lib, vars, ... }:

{
  # AyuGram Desktop - feature-rich Telegram fork
  # Features:
  # - Ghost mode (disable read receipts, typing indicators)
  # - Message scheduling
  # - Streamer mode
  # - Local folders and tags
  # - Many UI customizations
  
  # AyuGram is installed via home.packages in home.nix as ayugram-desktop
  # Stylix automatically handles GTK theming
  
  home-manager.users.${vars.username} = {
    # XDG desktop entry override for AyuGram (if needed)
    xdg.desktopEntries.ayugram-desktop = {
      name = "AyuGram";
      genericName = "Telegram Client";
      comment = "Feature-rich Telegram Desktop fork";
      exec = "ayugram-desktop -- %u";
      icon = "ayugram";
      terminal = false;
      type = "Application";
      categories = [ "Chat" "Network" "InstantMessaging" "Qt" ];
      mimeType = [ "x-scheme-handler/tg" ];
    };
  };
}
