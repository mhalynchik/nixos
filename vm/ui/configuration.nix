{ config, lib, pkgs, vars, modulesPath, ... }:

{
  imports = (import ../../lib/mkEnabledModules.nix { inherit vars lib; }) ++ [
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  virtualisation = {
    memorySize = 4096;
    cores = 4;
    diskSize = 16384;
    graphics = true;
    resolution = { x = 1280; y = 800; };
    useHostCerts = false;
    restrictNetwork = true;
    qemu.options = [ "-vga none" "-device virtio-vga-gl" ];
    sharedDirectories.control = {
      source = "$UI_VM_STATE/control";
      target = "/mnt/ui-vm-control";
      securityModel = "none";
    };
    forwardPorts = [{
      from = "host";
      host.address = "127.0.0.1";
      host.port = 22222;
      guest.port = 22;
    }];
  };

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.blacklistedKernelModules = [ "floppy" ];
  hardware.nvidia-container-toolkit.enable = lib.mkForce false;
  # Disposable UI sessions do not rotate logs. A shared store can have mapped
  # ownership in an agent container, which logrotate rejects as non-root-owned.
  services.logrotate.enable = lib.mkForce false;
  # Exercise the production greetd session model; a VM-only initial_session
  # previously hid the host's incorrect greeter-class desktop from lock tests.
  users.users.${vars.username}.initialPassword = "ui";
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkForce false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = lib.mkForce "no";
      AllowUsers = [ vars.username ];
    };
  };
  # The launcher generates the key outside the store and shares only its public half.
  systemd.services.sshd.unitConfig.RequiresMountsFor = "/mnt/ui-vm-control";
  systemd.services.sshd.preStart = lib.mkAfter ''
    install -Dm644 /mnt/ui-vm-control/ssh.pub /etc/ssh/authorized_keys.d/${vars.username}
  '';

  # Keep the existing desktop modules; only replace hardware-specific rendering.
  home-manager.users.${vars.username} = { lib, ... }: {
    # The wallpaper picker scans regular files, not Home Manager symlinks.
    home.activation.uiVmWallpaper = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.coreutils}/bin/install -Dm644 ${config.stylix.image} \
        "${vars.homeDirectory}/${vars.staticWallpapersDir}/${vars.defaultWallpaper}"
    '';
    home.sessionVariables = {
      GBM_BACKEND = lib.mkForce "dri";
      __GLX_VENDOR_LIBRARY_NAME = lib.mkForce "mesa";
      LIBVA_DRIVER_NAME = lib.mkForce "";
      WLR_RENDERER = lib.mkForce "gles2";
    };
    wayland.windowManager.hyprland.settings = {
      ecosystem.no_update_news = true;
      misc.disable_hyprland_logo = true;
      misc.disable_splash_rendering = true;
      animations.enabled = lib.mkForce false;
    };
    # Keep the real daemon and lock-session integration, but do not suspend an
    # unattended test VM. Tests can supply short idle listeners explicitly.
    services.hypridle.settings.listener = lib.mkForce [
      { timeout = 86400; on-timeout = "${pkgs.coreutils}/bin/true"; }
    ];
  };

  # Run commands with the graphical user's environment, including Wayland/IPC.
  environment.systemPackages = [ (pkgs.writeShellScriptBin "ui-session" ''
    set -eu
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
    HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.hyprland}/bin/hyprctl instances -j | ${pkgs.jq}/bin/jq -er '.[0].instance')
    WAYLAND_DISPLAY=$(${pkgs.hyprland}/bin/hyprctl instances -j | ${pkgs.jq}/bin/jq -er '.[0].wl_socket')
    export HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
    exec "$@"
  '') ];
}
