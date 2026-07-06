{ config, lib, pkgs, vars, ... }:

{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    max-jobs = 4;
    download-attempts = 5;
    cores = 3;
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  boot.kernel.sysctl."vm.swappiness" = 10;
  boot.kernelPackages = pkgs.linuxPackages;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "i2c-dev" "i2c-piix4" "bluetooth" "btusb" ];
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=1 disable_esco=1
  '';

  networking.hostName = vars.hostname;
  networking.networkmanager.enable = true;
  networking.useDHCP = false;

  services.resolved.enable = true;

  time.timeZone = vars.timezone;
  i18n.defaultLocale = vars.locale;
  i18n.supportedLocales = vars.supportedLocales;

  security.sudo = {
    enable = true;
    configFile = ''
      Defaults timestamp_timeout=120
    '';
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.gvfs.package = pkgs.gvfs;

  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "networkmanager" "bluetooth" ];
    packages = with pkgs; [ tree ];
  } // lib.optionalAttrs (vars.hashedPassword != null) {
    hashedPassword = vars.hashedPassword;
  };

  nixpkgs.config.permittedInsecurePackages = [
    "mbedtls-2.28.10"
    "ventoy-1.1.05"
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "nvidia-x11"
    "nvidia-settings"
    "steam"
    "steam-original"
    "steam-run"
    "steam-unwrapped"
    "vscode"
    "code"
    "vscode-extension-github-copilot"
    "vscode-extension-github-copilot-chat"
    "vscode-extension-MS-python-vscode-pylance"
    "google-chrome"
    "postman"
    "discord"
    "yandex-cloud"
    "spotify"
    "unityhub"
    "cuda_cudart"
    "libcublas"
    "cuda_cccl"
    "cuda_nvcc"
    "cuda-merged"
    "obsidian"
    "corefonts"
    "cursor"
    "ventoy"
  ];

  system.stateVersion = vars.stateVersion;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "03:45" ];
  };
}
