{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bibata-cursors
    cargo
    rustup
    bluez
    kitty
    wget
    curl
    unzip
    bat
    ffmpeg
    pkg-config
    just
    htop
    udiskie
    usbutils
    exfat
    ventoy-full
    swaylock
    pavucontrol
    kdePackages.dolphin
    kdePackages.qtsvg
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.breeze-icons
    nautilus
    ranger
    waybar
    wofi
    eww
  ];
}
