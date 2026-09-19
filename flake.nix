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

    # Do not follows our nixpkgs: AIRI needs their flake.lock (electron_41).
    # git+https avoids GitHub API 403 on `github:` fetch. Same commit as
    # tag v0.12.0-beta.1. Overlay in home/programs/airi is required.
    airi.url = "git+https://github.com/moeru-ai/airi.git?ref=v0.12.0-beta.1&rev=f14a7ac9a169290d2469a519c4387e3fe3ba2186";
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

      mkSystem = import ./lib/mk-system.nix;
      nixosSystem = mkSystem {
        inherit inputs system vars configDir;
        configurationModule = ./configuration.nix;
      };
      uiSystem = mkSystem {
        inherit inputs system;
        vars = import ./vm/ui/test-vars.nix { inherit lib; };
        configDir = "/etc/ui-vm";
        configurationModule = ./vm/ui/configuration.nix;
      };

      # Keep local aliases lazy enough to evaluate ui-test without host files.
      nixosConfigurations = (lib.optionalAttrs (builtins.pathExists varsPath) {
        ${vars.hostname} = nixosSystem;
      }) // {
        default = nixosSystem;
        nixos = nixosSystem;
        ui-test = uiSystem;
      };
    in
    {
      inherit nixosConfigurations;
    };
}
