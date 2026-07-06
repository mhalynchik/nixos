{ config, pkgs, vars, lib, ... }:

# Cursor AppImage -> Nix-пакет через appimageTools.wrapType2
# Обновление: положить AppImage в ~/.local/opt/cursor/ и rebuild --impure
let
  appImageHomePath = "${vars.homeDirectory}/.local/opt/cursor/cursor.AppImage";

  # Импорт AppImage в /nix/store. NAR-hash считается от содержимого файла.
  # При обновлении AppImage Nix перекопирует и пересоберёт пакет.
  cursorAppImage = builtins.path {
    name = "cursor.AppImage";
    path = appImageHomePath;
  };

  appImageVersion = "user-" + (builtins.substring 0 12
    (builtins.hashFile "sha256" cursorAppImage));

  # extraPkgs: рантайм-зависимости Electron в FHS-обёртке. Скопировано с
  # programs.nix-ld.libraries (configuration.nix) — там тот же набор для
  # электронных приложений типа Playwright.
  cursorRuntimeDeps = ps: with ps; [
    # Graphics
    libgbm
    mesa
    libGL
    libdrm
    libxkbcommon
    libglvnd

    # GTK / GLib
    glib
    gtk3
    gdk-pixbuf
    pango
    cairo
    atk
    at-spi2-atk
    at-spi2-core

    # X11 / XCB
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

    # Fonts / text
    fontconfig
    freetype
    expat

    # Networking / crypto
    nss
    nspr
    cups

    # Audio
    alsa-lib
    libpulseaudio

    # DBus / IPC / secrets
    dbus
    libsecret

    # Misc
    stdenv.cc.cc.lib
    zlib
  ];

  cursorPackage = pkgs.appimageTools.wrapType2 {
    pname = "cursor";
    version = appImageVersion;
    src = cursorAppImage;

    extraPkgs = cursorRuntimeDeps;

    extraBwrapArgs = [
      # Гарантируем наличие /etc/nixos внутри FHS
      "--bind" "/etc/nixos" "/etc/nixos"
      # На всякий случай можно добавить "--chdir" "/" или "$HOME",
      # но сначала попробуй просто bind
    ];

    # extraInstallCommands вызывается после установки бинаря. Оборачиваем
    # внешний cursor в shell-скрипт:
    #   1. --version короткозамкнут, чтобы coding-agent не поднимал Electron.
    #   2. По умолчанию запуск отвязан от терминала (новая сессия + фон), а
    #      stdout/stderr пишется в ~/.local/state/cursor/cursor.log. Терминал
    #      возвращает приглашение сразу, Electron-логи не мусорят в shell.
    #   3. CURSOR_DEBUG=1 cursor — запуск foreground с выводом в shell, для
    #      ручной отладки.
    extraInstallCommands = ''
      mv $out/bin/cursor $out/bin/cursor-bin
      cat > $out/bin/cursor <<SHIM
      #!${pkgs.bash}/bin/bash
      case "\$1" in
        --version|-v|-V)
          echo "Cursor (Nix-packaged AppImage ${appImageVersion})"
          exit 0
          ;;
      esac

      if [ -n "\$CURSOR_DEBUG" ]; then
        exec "$out/bin/cursor-bin" "\$@"
      fi

      LOG_DIR="\''${XDG_STATE_HOME:-\$HOME/.local/state}/cursor"
      mkdir -p "\$LOG_DIR"
      LOG_FILE="\$LOG_DIR/cursor.log"

      (
        setsid "$out/bin/cursor-bin" "\$@" </dev/null >"\$LOG_FILE" 2>&1 &
      )
      SHIM
      chmod +x $out/bin/cursor
    '';
  };
in
{
  home-manager.users.${vars.username} = {
    home.packages = [ cursorPackage ];
  };
}
