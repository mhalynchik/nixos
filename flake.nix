{
  description = "NixOS Configuration - Universal Hyprland Setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Curated HyDE Gallery theme, pinned by commit (NOT a floating branch).
    # Only allowlisted color/asset fields are consumed declaratively; see
    # home/themes/gallery/NOTICE.
    hyde-theme-catppuccin-mocha = {
      url = "github:HyDE-Project/hyde-themes/415d22a6bb6348a6d09c11307be54c592fb15138";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      configDirEnv = builtins.getEnv "NIXOS_CONFIG_DIR";
      configDir = if configDirEnv != "" then configDirEnv else builtins.toString ./.;
      varsPath = "${configDir}/vars.nix";

      varsDefaults = import ./vars.nix.example;

      varsUser =
        if builtins.pathExists varsPath then import varsPath
        else builtins.throw ''
          Файл vars.nix не найден: ${varsPath}

          Запустите wizard:
            ~/nixos-config/bin/setup

          Или создайте vars.nix вручную из vars.nix.example.
          Если /etc/nixos — git repo, vars.nix должен быть закоммичен.
          Для сборки из ~/nixos-config (vars в .gitignore):
            NIXOS_CONFIG_DIR=/etc/nixos nixos-rebuild build --flake /etc/nixos#default --impure
        '';

      vars = import ./lib/merge-vars.nix varsDefaults varsUser;

      # Curated Gallery domain: adapted palettes (pure) keyed by vars.theme.
      galleryThemes = import ./home/themes/gallery { inherit lib inputs; };

      colors = import ./home/themes/colors.nix {
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
          ./configuration.nix
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

      # nixos-rebuild на ISO часто запрашивает hostname "nixos", не "default"
      nixosConfigurations = lib.recursiveUpdate {
        default = nixosSystem;
        ${vars.hostname} = nixosSystem;
      } (lib.optionalAttrs (vars.hostname != "nixos") {
        nixos = nixosSystem;
      });
    in
    {
      inherit nixosConfigurations;
    };
}
