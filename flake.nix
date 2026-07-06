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
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      configDirEnv = builtins.getEnv "NIXOS_CONFIG_DIR";
      configDir = if configDirEnv != "" then configDirEnv else builtins.toString ./.;

      varsDefaults = import ./vars.nix.example;

      varsUser =
        if builtins.pathExists ./vars.nix then import ./vars.nix
        else builtins.throw ''
          Файл vars.nix не найден в конфигурации.

          Запустите wizard:
            ~/nixos-config/bin/setup

          Или создайте vars.nix вручную из vars.nix.example.
          Если /etc/nixos — git repo, vars.nix должен быть закоммичен.
        '';

      vars = import ./lib/merge-vars.nix varsDefaults varsUser;

      colors = import ./home/themes/colors.nix;

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
        specialArgs = { inherit inputs vars colors configDir pkgs-unstable; };
        modules = [
          ./configuration.nix
          inputs.stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs vars colors configDir pkgs-unstable; };
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
