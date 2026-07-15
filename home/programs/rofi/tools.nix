# Rofi picker utilities: emoji, glyph, web search, calculator.
{ pkgs, vars, browser }:

let
  emojiDb = ./data/emoji.db;
  glyphDb = ./data/glyph.db;
  websearchLst = ./data/websearch.lst;

  # Browser resolved centrally in flake.nix (unknown value already throws there).
  browserBin = browser.bin;

  emojiPicker = pkgs.writeShellApplication {
    name = "emoji-picker";
    runtimeInputs = with pkgs; [ rofi-wayland wl-clipboard libnotify coreutils gnugrep gawk ];
    text = ''
      set -euo pipefail
      selected=$(grep -v '^#' ${emojiDb} | rofi -dmenu -i -p "Emoji" | awk '{print $1}') || true
      if [ -z "$selected" ]; then exit 0; fi
      printf '%s' "$selected" | wl-copy
      notify-send "Emoji" "Copied to clipboard" -t 1500
    '';
  };

  glyphPicker = pkgs.writeShellApplication {
    name = "glyph-picker";
    runtimeInputs = with pkgs; [ rofi-wayland wl-clipboard libnotify coreutils gawk ];
    text = ''
      set -euo pipefail
      selected=$(rofi -dmenu -i -p "Glyph" < ${glyphDb}) || true
      if [ -z "$selected" ]; then exit 0; fi
      glyph=$(printf '%s' "$selected" | awk '{print $1}')
      printf '%s' "$glyph" | wl-copy
      notify-send "Glyph" "Copied to clipboard" -t 1500
    '';
  };

  rofiWebsearch = pkgs.writeShellApplication {
    name = "rofi-websearch";
    runtimeInputs = with pkgs; [ rofi-wayland jq libnotify coreutils gnused gnugrep gawk ];
    text = ''
      set -euo pipefail
      query=$(rofi -dmenu -i -p "Search") || true
      if [ -z "$query" ]; then exit 0; fi

      engine_url=""
      engine_name=""
      search_query="$query"
      # Match the engine prefix case-insensitively ("gh ", "GH ", "Gh " all work).
      query_lc="''${query,,}"

      while IFS='|' read -r _icon name url; do
        name=$(echo "$name" | xargs)
        url=$(echo "$url" | xargs)
        prefix="''${name,,}"
        if [[ "$query_lc" == "$prefix "* ]]; then
          engine_url="$url"
          engine_name="$name"
          # Strip "<prefix> " by length so original-case remainder is preserved.
          search_query="''${query:$(( ''${#prefix} + 1 ))}"
          break
        fi
      done < ${websearchLst}

      if [ -z "$engine_url" ]; then
        engine_url=$(grep -m1 '|' ${websearchLst} | awk -F'|' '{print $3}' | xargs)
        engine_name="Google"
      fi

      encoded=$(printf '%s' "$search_query" | jq -sRr @uri)
      ${browserBin} "''${engine_url}''${encoded}" &
      notify-send "Search" "$engine_name: $search_query" -t 2000
    '';
  };

  rofiCalc = pkgs.writeShellApplication {
    name = "rofi-calc";
    runtimeInputs = with pkgs; [ rofi-wayland libqalculate wl-clipboard libnotify coreutils ];
    text = ''
      set -euo pipefail
      expr=$(rofi -dmenu -i -p "Calculate") || true
      if [ -z "$expr" ]; then exit 0; fi
      result=$(qalc -t "$expr" 2>/dev/null) || {
        notify-send "Calculator" "Invalid expression" -u critical
        exit 1
      }
      printf '%s' "$result" | wl-copy
      notify-send "Calculator" "$result" -t 3000
    '';
  };

in
{
  packages = [ emojiPicker glyphPicker rofiWebsearch rofiCalc ];
}
