{ pkgs }:

pkgs.writeShellApplication {
  name = "desktop-screenshot";
  runtimeInputs = with pkgs; [ grim slurp wl-clipboard swappy coreutils ];
  text = ''
    mode="''${1:-clipboard}"
    case "$mode" in
      clipboard|file|edit) ;;
      *) echo "Usage: desktop-screenshot [clipboard|file|edit]" >&2; exit 2 ;;
    esac

    # Escape must leave the clipboard, files and editor untouched.
    geometry=$(slurp) || exit 0
    [ -n "$geometry" ] || exit 0
    image=$(mktemp --suffix=.png)
    trap 'rm -f "$image"' EXIT
    grim -g "$geometry" "$image"

    case "$mode" in
      clipboard) wl-copy --type image/png < "$image" ;;
      file)
        directory="$HOME/Pictures/Screenshots"
        mkdir -p "$directory"
        mv "$image" "$directory/$(date +%Y-%m-%d_%H-%M-%S_%N).png"
        ;;
      edit) swappy -f "$image" ;;
    esac
  '';
}
