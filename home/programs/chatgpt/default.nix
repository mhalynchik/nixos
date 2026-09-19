{ pkgs, lib, vars, ... }:

# Официальный ChatGPT desktop (.deb). nixpkgs.chatgpt — только Darwin.
# Pin the versioned repository artifact: the /latest/ URL changes in place.
# Updates: read Version, Filename and SHA256 from the official APT Packages index:
# https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages
let
  version = "26.908.70816";
  chatgpt = pkgs.stdenv.mkDerivation {
    pname = "chatgpt";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
      hash = "sha256-EO0MGogLmXXR8YW/eRGn9RTga5hjzU7ZVh1ABjYXyFQ=";
    };

    nativeBuildInputs = [
      pkgs.dpkg
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
      pkgs.wrapGAppsHook3
      pkgs.python3
    ];

    # wrapGAppsHook3 fills gappsWrapperArgs; we wrap only the three bins.
    dontWrapGApps = true;

    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      glib
      gtk3
      gsettings-desktop-schemas
      gdk-pixbuf
      shared-mime-info
      pango
      libdrm
      libgbm
      libGL
      libglvnd
      libnotify
      libpulseaudio
      libsecret
      libusb1
      libxkbcommon
      mesa
      nss
      nspr
      stdenv.cc.cc.lib
      udev
      zlib
      xorg.libX11
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libxshmfence
      xorg.libXtst
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libQt5Core.so.5"
      "libQt5Gui.so.5"
      "libQt5Widgets.so.5"
      "libQt6Core.so.6"
      "libQt6Gui.so.6"
      "libQt6OpenGL.so.6"
      "libQt6Widgets.so.6"
      "libc.musl-x86_64.so.1"
    ];

    runtimeDependencies = with pkgs; [
      libGL
      mesa
      udev
    ];

    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib $out/share $out/bin
      cp -a usr/lib/chatgpt $out/lib/
      cp -a usr/share/applications $out/share/
      cp -a usr/share/pixmaps $out/share/
      cp -a usr/share/metainfo $out/share/

      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp $out/share/pixmaps/chatgpt.png $out/share/icons/hicolor/512x512/apps/chatgpt.png

      substituteInPlace $out/share/applications/chatgpt.desktop \
        --replace-fail "MimeType=x-scheme-handler/codex;x-scheme-handler/http;x-scheme-handler/https;text/csv;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.openxmlformats-officedocument.presentationml.presentation;text/tab-separated-values;application/vnd.ms-excel;application/vnd.ms-excel.sheet.macroEnabled.12;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;" \
          "MimeType=x-scheme-handler/codex;"

      # autoPatchelf moves PT_INTERP past detect-libc's 2KiB scan. process.report
      # fallback then hits Electron CFI = SIGILL on git-repo-watcher (nixpkgs#551713).
      # Same-length replacements: asar offsets stay valid.
      python3 - "$out/lib/chatgpt/resources/app.asar" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes()
repls = [
    (b"const family = familySync();", b"const family = 'glibc';     "),
    (b"isLinux() && process.report", b"false /* nix:skip report */"),
]
for old, new in repls:
    if len(old) != len(new):
        raise SystemExit(f"length mismatch {old!r} {len(old)} vs {len(new)}")
    n = data.count(old)
    if n != 1:
        raise SystemExit(f"expected 1 {old!r}, got {n}")
    data = data.replace(old, new)
p.write_bytes(data)
PY

      runHook postInstall
    '';

    # Native Wayland на Hyprland роняет Electron (Connection reset by peer).
    # Официальный Linux preview сам идёт в XWayland. NIXOS_OZONE_WL=1 это ломает.
    # gappsWrapperArgs: gtk3 FileChooser schema. Без неё Open Folder = GLib-GIO-ERROR.
    # Launch script: writable plugin tree + bwrap bind over store (else EACCES).
    preFixup = ''
      mkdir -p $out/libexec
      makeWrapper $out/lib/chatgpt/ChatGPT $out/libexec/chatgpt-electron \
        "''${gappsWrapperArgs[@]}" \
        --prefix PATH : ${lib.makeBinPath [ pkgs.procps pkgs.coreutils pkgs.findutils ]}

      substitute ${./chatgpt-launch.sh} $out/libexec/chatgpt-launch \
        --replace-fail '@plugins@' "$out/lib/chatgpt/resources/plugins/openai-bundled" \
        --replace-fail '@electron@' "$out/libexec/chatgpt-electron" \
        --replace-fail '@bwrap@' "${pkgs.bubblewrap}/bin/bwrap"
      chmod +x $out/libexec/chatgpt-launch

      wrapLaunch() {
        local name="$1"
        shift
        makeWrapper $out/libexec/chatgpt-launch "$out/bin/$name" \
          --prefix PATH : ${lib.makeBinPath [ pkgs.procps pkgs.coreutils pkgs.findutils pkgs.bubblewrap ]} \
          "$@"
      }

      wrapLaunch chatgpt \
        --unset NIXOS_OZONE_WL \
        --set ELECTRON_OZONE_PLATFORM_HINT x11 \
        --set CHATGPT_ELECTRON_FLAGS "--ozone-platform=x11"

      wrapLaunch chatgpt-x11 \
        --unset NIXOS_OZONE_WL \
        --set ELECTRON_OZONE_PLATFORM_HINT x11 \
        --set CHATGPT_ELECTRON_FLAGS "--ozone-platform=x11"

      wrapLaunch chatgpt-wayland \
        --set CHATGPT_ELECTRON_FLAGS "--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true"
    '';

    meta = {
      description = "ChatGPT desktop app";
      homepage = "https://developers.openai.com/codex/app";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = "chatgpt";
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  home-manager.users.${vars.username} = {
    home.packages = [ chatgpt ];
  };
}
