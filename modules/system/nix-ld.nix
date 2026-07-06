{ config, lib, pkgs, vars, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glib
      xorg.libX11
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXcomposite
      xorg.libxcb
      xorg.libxshmfence
      gtk3
      gdk-pixbuf
      pango
      cairo
      atk
      alsa-lib
      pulseaudio
      fontconfig
      freetype
      dbus
      nss
      nspr
      expat
      cups
      libdrm
      mesa
      libxkbcommon
      at-spi2-atk
      at-spi2-core
    ]
    ++ lib.optionals vars.features.deepcool [
      qt6.qtbase
      libusb1
      systemd
      icu
      pcre2
      double-conversion
      libb2
      zstd
    ];
  };
}
