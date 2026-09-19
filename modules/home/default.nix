{ config, lib, pkgs, pkgs-unstable, vars, ... }:

{
  imports = [
    ../../home/programs
    ../../home/themes
  ];

  home-manager.users.${vars.username} = {
    home.stateVersion = vars.stateVersion;
    home.username = vars.username;
    home.homeDirectory = vars.homeDirectory;

    programs.obs-studio.enable = true;
    # Stylix targets configure these modules; installing bare packages alone
    # does not generate their theme files.
    programs.btop.enable = true;
    programs.lazygit.enable = true;
    programs.vim.enable = true;
    programs.neovim.enable = true;
    programs.bat.enable = true;
    programs.fzf.enable = true;

    home.packages =
      (with pkgs; [
        wlr-randr
        wl-clipboard
        cliphist
        pulsemixer
        pamixer
        brightnessctl
        tty-clock
        tokyonight-gtk-theme
        zenity
        gnome-tweaks
        fastfetch
        gradience
        gimp
        catimg
        grim
        slurp
        eog
        viewnior
        tesseract4
        swappy
        nano
        gedit
        git
        nodejs_22
        uv
        sqlite
        gcc
        gnumake
        xfce.thunar
        xfce.thunar-volman
        xfce.thunar-archive-plugin
        xfce.tumbler
        ffmpegthumbnailer
        networkmanagerapplet
        networkmanager_dmenu
        blueman
        mpc
        mpv
        playerctl
        celluloid
      ])
      ++ lib.optionals vars.features.openWebui (with pkgs-unstable; [ open-webui cloudflared ])
      ++ lib.optionals vars.features.nvidia (with pkgs-unstable; [ nvidia-container-toolkit ])
      ++ lib.optionals vars.features.devTools (with pkgs; [
        exercism
        speedread
        qbittorrent
        onlyoffice-desktopeditors
        obsidian
        postman
        unityhub
        nil
        nixpkgs-fmt
        gitleaks
        pyright
        black
        isort
        python3Packages.debugpy
        omnisharp-roslyn
        netcoredbg
        dotnet-sdk_8
        (python3.withPackages (ps: with ps; [
          pandas
          requests
          pip
          notebook
          jupyter
          ipykernel
        ]))
      ])
      ++ lib.optionals vars.programs.lunarvim (with pkgs; [ lunarvim ])
      ++ lib.optionals vars.programs.codex (with pkgs-unstable; [ codex ])
      ++ lib.optionals vars.programs.planify (with pkgs; [ planify ])
      ++ lib.optionals vars.programs.spotify (with pkgs; [ lollypop cava ])
      ++ lib.optionals vars.programs.telegram (with pkgs; [
        ayugram-desktop
        simplex-chat-desktop
      ])
      ++ lib.optionals vars.programs.discord (with pkgs; [
        discord
        betterdiscord-installer
      ])
      ++ lib.optionals vars.features.gaming (with pkgs; [ lutris openrgb ])
      ++ lib.optionals vars.programs.ags (with pkgs; [ eww ])
      ++ lib.optionals (vars.features.devTools || vars.programs.vscode) (with pkgs; [
        awscli
        yandex-cloud
        taskwarrior3
        tasksh
      ]);

    programs.git = {
      enable = true;
      userName = vars.gitUsername;
      userEmail = vars.gitEmail;
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };
  };
}
