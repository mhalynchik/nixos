{ config, pkgs, lib, vars, colors, inputs, ... }:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  home-manager.users.${vars.username} = {
    # Spicetify configuration with Catppuccin theme
    # Module is imported via home-manager.sharedModules in flake.nix
    programs.spicetify = {
      enable = true;

      # Theme settings
      theme = spicePkgs.themes.catppuccin;
      # Keep the Catppuccin layout, but derive every color from vars.theme.
      customColorScheme = lib.mapAttrs (_: lib.removePrefix "#") (colors.colors // {
        text = colors.colors.text;
        subtext = colors.colors.subtext0;
        main = colors.colors.base;
        sidebar = colors.colors.mantle;
        player = colors.colors.crust;
        card = colors.colors.surface0;
        shadow = colors.colors.crust;
        selected-row = colors.colors.overlay0;
        button = colors.colors.accent;
        button-active = colors.colors.accent;
        button-disabled = colors.colors.surface2;
        tab-active = colors.colors.surface1;
        notification = colors.colors.surface0;
        notification-error = colors.colors.error;
        equalizer = colors.colors.accent;
        misc = colors.colors.surface2;
        highlight = colors.colors.surface1;
        main-elevated = colors.colors.surface0;
        highlight-elevated = colors.colors.surface2;
      });

      # Extensions
      enabledExtensions = with spicePkgs.extensions; [
        adblock           # Block ads
        hidePodcasts      # Hide podcasts from home
        shuffle           # Shuffle+ for better shuffling
        fullAppDisplay    # Full screen display mode
        keyboardShortcut  # Additional keyboard shortcuts
        playlistIcons     # Custom playlist icons
        history           # Listen history
        bookmark          # Bookmark tracks
      ];

      # Custom apps
      enabledCustomApps = with spicePkgs.apps; [
        newReleases       # New releases page
        lyricsPlus        # Better lyrics
      ];

      # Visual snippets
      enabledSnippets = with spicePkgs.snippets; [
        rotatingCoverart  # Rotating album art
        pointer           # Custom pointer
      ];
    };
  };
}
