# HyDE Gallery asset unpacking: GTK/icon archives become read-only Nix
# derivations (never extracted into $HOME during activation). Wallpapers are
# exposed as a read-only store path for the wallpaper domain.
{ pkgs, source, def }:

let
  themePath = "${source}/${def.themeSubdir}";

  # Extract an archive without honoring embedded owner/permission metadata and
  # verify the expected top-level directory is present. tar only extracts data;
  # no theme code is executed. The archive is screened before and after
  # extraction so an unsafe member can never land outside the store output:
  #   1. member names: no absolute path, no ".." traversal;
  #   2. symlink/hardlink targets: no absolute target;
  #   3. after extraction: no symlink resolves outside the extraction root
  #      (catches relative ".." link targets that escape).
  # A missing expected directory afterwards also fails the build.
  _unpackArchive = { archive, themeName, shareSubdir }:
    pkgs.runCommand "hyde-gallery-${themeName}" { } ''
      dest="$out/share/${shareSubdir}"
      mkdir -p "$dest"

      # 1. Reject unsafe member names (absolute paths or parent traversal).
      if tar --list --file ${source}/${archive} \
        | grep -Eq '^/|(^|/)\.\.(/|$)'; then
        echo "HyDE Gallery assets: unsafe member name (absolute or '..') in ${archive}" >&2
        exit 1
      fi

      # 2. Reject symlink/hardlink members whose target is an absolute path.
      if tar --list --verbose --file ${source}/${archive} \
        | sed -nE 's/.* -> (.*)$/\1/p; s/.* link to (.*)$/\1/p' \
        | grep -Eq '^/'; then
        echo "HyDE Gallery assets: absolute symlink/hardlink target in ${archive}" >&2
        exit 1
      fi

      tar --extract --no-same-owner --no-same-permissions \
        --file ${source}/${archive} --directory "$dest"

      # 3. Reject any extracted symlink that resolves outside the extraction root.
      destc=$(realpath -m "$dest")
      while IFS= read -r -d "" link; do
        tgt=$(realpath -m -- "$link")
        case "$tgt" in
          "$destc"|"$destc"/*) ;;
          *)
            echo "HyDE Gallery assets: symlink '$link' -> '$tgt' escapes extraction root ($destc)" >&2
            exit 1
            ;;
        esac
      done < <(find "$dest" -type l -print0)

      if [ ! -d "$dest/${themeName}" ]; then
        echo "HyDE Gallery assets: expected directory '${themeName}' not found after extracting ${archive}" >&2
        echo "Top-level entries actually extracted:" >&2
        ls -1A "$dest" >&2 || true
        exit 1
      fi
    '';
in
{
  wallpaperDir = "${themePath}/${def.wallpapersSubdir}";

  gtkTheme = {
    name = def.gtk.themeName;
    package = _unpackArchive {
      inherit (def.gtk) archive themeName;
      shareSubdir = "themes";
    };
  };

  iconTheme = {
    name = def.icon.themeName;
    package = _unpackArchive {
      inherit (def.icon) archive themeName;
      shareSubdir = "icons";
    };
  };
}
