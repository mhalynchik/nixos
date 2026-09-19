{ inputs, system, vars, configDir, configurationModule }:

let
  inherit (inputs) nixpkgs home-manager;
  nixpkgs-unstable = inputs.nixpkgs-unstable;
  lib = nixpkgs.lib;
  # Curated Gallery domain: adapted palettes (pure) keyed by vars.theme.
  galleryThemes = import ../home/themes/gallery { inherit lib inputs; };

  colors = import ../home/themes/colors.nix {
    inherit vars;
    galleryPalettes = galleryThemes.palettes;
    galleryGtkThemeName = galleryThemes.gtkThemeNameFor vars.theme;
    galleryIconThemeName = galleryThemes.iconThemeNameFor vars.theme;
  };

  # Single source of truth for the selected browser: package + binary path.
  # Everything (Hyprland $browser, exec-once autostart, rofi web search,
  # installed package) must reference the same derivation.
  browserOptions = {
    floorp = { package = pkgs-unstable.floorp-bin; binName = "floorp"; };
    librewolf = { package = pkgs.librewolf; binName = "librewolf"; };
  };
  browserChoice =
    browserOptions.${vars.browser}
      or (builtins.throw "Unsupported browser: ${vars.browser} (allowed: ${lib.concatStringsSep ", " (builtins.attrNames browserOptions)})");
  browser = {
    package = browserChoice.package;
    bin = "${browserChoice.package}/bin/${browserChoice.binName}";
  };

  wlClipboardOverlay = final: prev: {
    wl-clipboard = prev.wl-clipboard.overrideAttrs (_: {
      version = "2.3.0";
      src = prev.fetchFromGitHub {
        owner = "bugaevc";
        repo = "wl-clipboard";
        rev = "v2.3.0";
        hash = "sha256-c/EfjrA4H/MiedSVWLN6ZUipxwcsmBueeYJu5b09MGc=";
      };
    });
  };

  # Plain nixpkgs used only to resolve the librewolf browser package at
  # flake-eval time (browser SSOT). The system pkgs (with wlClipboardOverlay)
  # is built by the NixOS module system via nixpkgs.overlays below.
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  pkgs-unstable = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };

  nixosSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs vars colors configDir pkgs-unstable browser; };
    modules = [
      configurationModule
      inputs.stylix.nixosModules.stylix
      home-manager.nixosModules.home-manager
      # Apply the overlay to the system pkgs; useGlobalPkgs propagates it to
      # Home Manager, so wl-clipboard 2.3.0 reaches cliphist watchers and
      # clipboard-picker.
      { nixpkgs.overlays = [ wlClipboardOverlay ]; }
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs vars colors configDir pkgs-unstable browser; };
        home-manager.backupFileExtension = "backup";
        home-manager.sharedModules = lib.optionals vars.programs.spotify [
          inputs.spicetify-nix.homeManagerModules.default
        ];
      }
    ];
  };

in
nixosSystem
