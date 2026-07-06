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
      system = "x86_64-linux";

      configDirEnv = builtins.getEnv "NIXOS_CONFIG_DIR";
      configDir = if configDirEnv != "" then configDirEnv else builtins.toString ./.;

      vars =
        if builtins.pathExists ./vars.nix then import ./vars.nix
        else builtins.throw ''
          Файл vars.nix не найден.

          Первый запуск:
            git clone <repo-url> ~/nixos-config
            cd ~/nixos-config
            ./bin/setup

          Обновление:
            ~/nixos-config/bin/update
        '';

      colors = import ./home/themes/colors.nix;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
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
            home-manager.sharedModules = [
              inputs.spicetify-nix.homeManagerModules.default
            ];
          }
        ];
      };

      nixosConfigurations.default = self.nixosConfigurations.${vars.hostname};
    };
}
