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
      colorScheme = "mocha";

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
