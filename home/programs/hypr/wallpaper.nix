# Wallpaper domain: wallpaper-set, picker, thin wrappers, symlink management.
# galleryWallpaperDir: optional read-only store dir with curated Gallery
# wallpapers, added to the static search path (empty string = disabled).
{ pkgs, vars, galleryWallpaperDir ? "" }:

let
  home = vars.homeDirectory;
  staticDir = "${home}/${vars.staticWallpapersDir}";
  animatedDir = "${home}/${vars.animatedWallpapersDir}";
  galleryDir = galleryWallpaperDir;
  stateDir = "${home}/.local/state";
  cacheDir = "${home}/.cache/wallpaper-thumbs";
  desktopSymlink = "${stateDir}/current-wallpaper";
  lockSymlink = "${stateDir}/current-lock-wallpaper";
  lockCache = "${home}/.cache/wallpaper-lock.png";
  lockCacheTmp = "${home}/.cache/wallpaper-lock.tmp.png";
  defaultWallpaper =
    if vars ? defaultWallpaper && vars.defaultWallpaper != null && vars.defaultWallpaper != ""
    then "${staticDir}/${vars.defaultWallpaper}"
    else "";

  wallpaperRuntimeInputs = with pkgs; [
    coreutils
    findutils
    imagemagick
    ffmpeg
    swww
    systemd
    util-linux
    rofi-wayland
    libnotify
    gnused
    gnugrep
    gawk
    jq
  ];

  # mpvpaper options shared between wallpaper-set (none now) and the service.
  mpvOpts = "no-audio loop --hwdec=no --no-cache --profile=low-latency --vd-lavc-threads=1 --video-sync=display-resample --no-config";

  # ExecStart for the animated-wallpaper systemd user service. Runs a SINGLE
  # foreground mpvpaper on the current-wallpaper symlink. It never changes the
  # wallpaper, regenerates the lock frame, or notifies: those are wallpaper-set's
  # job. A missing/broken/non-animated symlink exits 3 (RestartPreventExitStatus)
  # so the periodic 45-min recycle and Restart=always never turn into a loop.
  animatedWallpaperRunner = pkgs.writeShellApplication {
    name = "animated-wallpaper-runner";
    runtimeInputs = with pkgs; [ mpvpaper coreutils ];
    text = ''
      set -euo pipefail
      target=$(readlink -f "${desktopSymlink}" 2>/dev/null) || exit 3
      { [ -n "$target" ] && [ -f "$target" ]; } || exit 3
      ext="''${target##*.}"
      ext_lower=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
      case "$ext_lower" in
        gif|mp4|webm|mkv) ;;
        *) exit 3 ;;
      esac
      exec mpvpaper -o "${mpvOpts}" '*' "$target"
    '';
  };

  animatedWallpaperService = {
    Unit = {
      Description = "Animated wallpaper (mpvpaper) for current-wallpaper symlink";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "simple";
      ExecStart = "${animatedWallpaperRunner}/bin/animated-wallpaper-runner";
      Restart = "always";
      RestartSec = "1s";
      # Periodic recycle bounds mpvpaper RSS growth (RAM leak workaround).
      RuntimeMaxSec = "45min";
      KillMode = "control-group";
      # exit 3 = nothing to animate (missing/static/broken/non-animated symlink):
      # treat as clean success (no failed unit) AND do not restart-loop.
      SuccessExitStatus = 3;
      RestartPreventExitStatus = 3;
    };
    # No WantedBy autostart: wallpaper-set starts the unit only for animated
    # wallpapers, so a static session never leaves it in a failed state.
    # PartOf still stops mpvpaper when the graphical session ends.
  };

  wallpaperSet = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = wallpaperRuntimeInputs;
    text = ''
      set -euo pipefail

      arg="''${1:-}"
      if [ -z "$arg" ]; then
        notify-send "Wallpaper" "No path given" -u critical
        exit 1
      fi
      # Accept absolute paths as-is; resolve relative paths against $HOME.
      case "$arg" in
        /*) WALLPAPER="$arg" ;;
        *)  WALLPAPER="$HOME/$arg" ;;
      esac
      if [ ! -f "$WALLPAPER" ]; then
        notify-send "Wallpaper" "File not found: $WALLPAPER" -u critical
        exit 1
      fi

      mkdir -p "${stateDir}" "${cacheDir}"

      # Serialize every wallpaper-set run for the whole script: a concurrent
      # picker/next/startup must not interleave the animated service stop/start
      # and leave mpvpaper running on top of a static wallpaper.
      exec 9>"${stateDir}/.wallpaper-set.lock"
      flock 9

      ext="''${WALLPAPER##*.}"
      ext_lower=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')

      is_video=false
      case "$ext_lower" in
        mp4|webm|mkv|gif) is_video=true ;;
      esac

      # Atomically repoint current-wallpaper at the new file. Use a real unique
      # temp dir (mktemp -d), not a predictable mktemp -u name, then rename.
      _set_current_symlink() {
        _tmpd=$(mktemp -d "${stateDir}/.current-wallpaper.XXXXXX")
        ln -s "$1" "$_tmpd/link"
        mv -Tf "$_tmpd/link" "${desktopSymlink}"
        rmdir "$_tmpd"
      }

      if [ "$is_video" = true ]; then
        _set_current_symlink "$WALLPAPER"
        # Lock-screen frame is generated exactly once, here (not on restarts).
        tmp_lock="${lockCacheTmp}"
        if ffmpeg -y -i "$WALLPAPER" -vframes 1 -f image2 "$tmp_lock" 2>/dev/null; then
          mv -f "$tmp_lock" "${lockCache}"
          ln -sf "${lockCache}" "${lockSymlink}"
        else
          rm -f "$tmp_lock"
        fi
        # A single mpvpaper instance is owned by the systemd user service.
        systemctl --user restart animated-wallpaper.service
      else
        # Static: stop the animated service (control-group kills mpvpaper), swww.
        systemctl --user stop animated-wallpaper.service 2>/dev/null || true
        swww init 2>/dev/null || true
        swww img "$WALLPAPER" --transition-type random --transition-fps 60 --transition-duration 2
        _set_current_symlink "$WALLPAPER"
        ln -sf "$WALLPAPER" "${lockSymlink}"
      fi

      notify-send "Wallpaper" "$(basename "$WALLPAPER")" -t 2000
    '';
  };

  wallpaperStatic = pkgs.writeShellApplication {
    name = "wallpaper-static";
    runtimeInputs = wallpaperRuntimeInputs;
    text = ''
      set -euo pipefail
      _dirs=()
      [ -d "${staticDir}" ] && _dirs+=("${staticDir}")
      _gallery_dir="${galleryDir}"
      [ -n "$_gallery_dir" ] && [ -d "$_gallery_dir" ] && _dirs+=("$_gallery_dir")
      if [ ''${#_dirs[@]} -eq 0 ]; then
        notify-send "Wallpaper" "Static directory not found" -u critical
        exit 1
      fi
      mapfile -d "" -t _candidates < <(find "''${_dirs[@]}" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
      if [ ''${#_candidates[@]} -eq 0 ]; then
        notify-send "Wallpaper" "No static wallpapers found" -u critical
        exit 1
      fi
      exec wallpaper-set "''${_candidates[RANDOM % ''${#_candidates[@]}]}"
    '';
  };

  wallpaperAnimated = pkgs.writeShellApplication {
    name = "wallpaper-animated";
    runtimeInputs = wallpaperRuntimeInputs;
    text = ''
      set -euo pipefail
      SEARCH_DIR="${animatedDir}"
      if [ ! -d "$SEARCH_DIR" ]; then
        exit 1
      fi
      mapfile -d "" -t _candidates < <(find "$SEARCH_DIR" -type f \( -name "*.gif" -o -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) -print0 2>/dev/null)
      if [ ''${#_candidates[@]} -eq 0 ]; then
        exit 1
      fi
      exec wallpaper-set "''${_candidates[RANDOM % ''${#_candidates[@]}]}"
    '';
  };

  wallpaperNext = pkgs.writeShellApplication {
    name = "wallpaper-next";
    runtimeInputs = wallpaperRuntimeInputs;
    text = ''
      set -euo pipefail
      _dirs=()
      [ -d "${staticDir}" ] && _dirs+=("${staticDir}")
      _gallery_dir="${galleryDir}"
      [ -n "$_gallery_dir" ] && [ -d "$_gallery_dir" ] && _dirs+=("$_gallery_dir")
      if [ ''${#_dirs[@]} -eq 0 ]; then
        notify-send "Wallpaper" "No static wallpapers found" -u critical
        exit 1
      fi
      mapfile -d "" -t _candidates < <(find "''${_dirs[@]}" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
      if [ ''${#_candidates[@]} -eq 0 ]; then
        notify-send "Wallpaper" "No static wallpapers found" -u critical
        exit 1
      fi
      exec wallpaper-set "''${_candidates[RANDOM % ''${#_candidates[@]}]}"
    '';
  };

  wallpaperStartup = pkgs.writeShellApplication {
    name = "wallpaper-startup";
    runtimeInputs = wallpaperRuntimeInputs;
    text = ''
      set -euo pipefail
      if wallpaper-animated; then
        exit 0
      fi
      if wallpaper-static; then
        exit 0
      fi
      DEFAULT="${defaultWallpaper}"
      if [ -n "$DEFAULT" ] && [ -f "$DEFAULT" ]; then
        exec wallpaper-set "$DEFAULT"
      fi
      notify-send "Wallpaper" "No wallpaper available" -u low
      exit 0
    '';
  };

  wallpaperPicker = pkgs.writeShellApplication {
    name = "wallpaper-picker";
    runtimeInputs = wallpaperRuntimeInputs;
    text = ''
      set -euo pipefail
      MANIFEST="${cacheDir}/manifest.json"
      mkdir -p "${cacheDir}"

      # Only one interactive picker at a time: a second invocation is a no-op
      # instead of stacking rofi menus and racing the shared thumbnail manifest.
      exec 8>"${cacheDir}/.picker.lock"
      flock -n 8 || exit 0

      _dirs=()
      [ -d "${staticDir}" ] && _dirs+=("${staticDir}")
      _gallery_dir="${galleryDir}"
      [ -n "$_gallery_dir" ] && [ -d "$_gallery_dir" ] && _dirs+=("$_gallery_dir")
      if [ ''${#_dirs[@]} -eq 0 ]; then
        notify-send "Wallpaper" "Static directory not found" -u critical
        exit 1
      fi

      if [ ! -f "$MANIFEST" ]; then
        echo '{}' > "$MANIFEST"
      fi

      # Rofi input built in a temp file (never keep NUL bytes in a shell var).
      # One newline-terminated record per file: "text\0icon\x1f<thumb>".
      ROFI_INPUT="$(mktemp)"
      trap 'rm -f "$ROFI_INPUT"' EXIT

      declare -A seen_ids=()
      while IFS= read -r -d $'\0' file; do
        wallpaper_id=$(printf '%s' "$file" | sha256sum | awk '{print $1}')
        seen_ids["$wallpaper_id"]=1
        mtime=$(stat -c %Y "$file")
        thumb="${cacheDir}/''${wallpaper_id}.png"
        stored_mtime=$(jq -r --arg id "$wallpaper_id" '.[$id].mtime // empty' "$MANIFEST")
        if [ "$stored_mtime" != "$mtime" ] || [ ! -f "$thumb" ]; then
          convert "$file" -thumbnail 200x112^ -gravity center -extent 200x112 "$thumb" 2>/dev/null || cp "$file" "$thumb"
          jq --arg id "$wallpaper_id" --arg path "$file" --argjson mtime "$mtime" --arg thumb "$thumb" \
            '.[$id] = {path: $path, mtime: $mtime, thumbnail: $thumb}' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
        fi
        name=$(basename "$file")
        printf '%s\0icon\x1f%s\n' "''${wallpaper_id}  ''${name}" "$thumb" >> "$ROFI_INPUT"
      done < <(find "''${_dirs[@]}" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)

      # Drop manifest entries and thumbnails of wallpapers that no longer exist.
      while IFS= read -r stored_id; do
        [ -n "$stored_id" ] || continue
        if [ -z "''${seen_ids[$stored_id]:-}" ]; then
          rm -f "${cacheDir}/''${stored_id}.png"
          jq --arg id "$stored_id" 'del(.[$id])' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
        fi
      done < <(jq -r 'keys[]' "$MANIFEST")

      if [ ! -s "$ROFI_INPUT" ]; then
        notify-send "Wallpaper" "No wallpapers found" -u critical
        exit 1
      fi

      selected=$(rofi -dmenu -i -p "Wallpaper" -show-icons < "$ROFI_INPUT") || true
      if [ -z "$selected" ]; then
        exit 0
      fi
      selected_id=$(printf '%s' "$selected" | awk '{print $1}')

      path=$(jq -r --arg id "$selected_id" '.[$id].path // empty' "$MANIFEST")
      if [ -z "$path" ] || [ ! -f "$path" ]; then
        notify-send "Wallpaper" "Selected wallpaper not found" -u critical
        exit 1
      fi
      # exec replaces the shell, so the EXIT trap never fires: clean up manually.
      rm -f "$ROFI_INPUT"
      trap - EXIT
      exec wallpaper-set "$path"
    '';
  };

  initWallpaperSymlinksScript = ''
    mkdir -p ${stateDir}
    DEFAULT="${defaultWallpaper}"
    if [ -n "$DEFAULT" ] && [ -f "$DEFAULT" ]; then
      if [ ! -e ${desktopSymlink} ]; then
        ln -sf "$DEFAULT" ${desktopSymlink}
      fi
      if [ ! -e ${lockSymlink} ]; then
        ln -sf "$DEFAULT" ${lockSymlink}
      fi
    fi
  '';

in
{
  packages = [
    wallpaperSet
    wallpaperStatic
    wallpaperAnimated
    wallpaperNext
    wallpaperStartup
    wallpaperPicker
  ];
  inherit initWallpaperSymlinksScript desktopSymlink lockSymlink;
  inherit animatedWallpaperService;
}
