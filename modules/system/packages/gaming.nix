{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gamescope
    mangohud
    gamemode
    xorg.xhost
    vulkan-tools
    vulkan-loader
    lutris
    bottles
    (wineWowPackages.stagingFull.override { waylandSupport = true; })
    winetricks
    dxvk
    vkd3d-proton
    giflib
    libpng
    libjpeg
    openldap
    gnutls
    libgpg-error
    libgcrypt
    mpg123
    openal
    libpulseaudio
    alsa-lib
    alsa-plugins
    v4l-utils
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    libva
    xorg.libXcomposite
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libXxf86vm
    sqlite
    ncurses
    libxslt
    gtk3
    ocl-icd
  ];
}
