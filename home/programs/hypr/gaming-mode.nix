# Hyprland gaming profile toggle (visual effects off, not Feral gamemode).
{ pkgs, vars, lib }:

let
  gamingMode = pkgs.writeShellApplication {
    name = "gaming-mode";
    runtimeInputs = with pkgs; [ hyprland jq procps coreutils ];
    text = ''
      set -euo pipefail

      WAYBAR_SIGNAL=8
      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/gaming-mode.state"

      # Options toggled by the gaming profile (order = restore order).
      TOGGLED_OPTIONS="animations:enabled decoration:blur:enabled decoration:shadow:enabled decoration:rounding general:gaps_in general:gaps_out"

      _status() {
        hyprctl getoption animations:enabled -j | jq -e '.int == 0' >/dev/null 2>&1 && echo on || echo off
      }

      _notify_waybar() {
        pkill -RTMIN+''${WAYBAR_SIGNAL} waybar 2>/dev/null || true
      }

      # gaps_in/gaps_out are CCssGapData: their value lives in .custom ("5 5 5 5"),
      # not .int. Read whichever field carries the value.
      _get_value() {
        hyprctl getoption "$1" -j 2>/dev/null | jq -r '.int // .float // .custom // empty' 2>/dev/null || true
      }

      _on() {
        # Idempotent: snapshot only when currently off, so re-running `on` while
        # already active never overwrites the saved values with zeros.
        if [ "$(_status)" != "on" ]; then
          : > "$STATE_FILE"
          for opt in $TOGGLED_OPTIONS; do
            # Tab-separated so multi-word values (e.g. "5 5 5 5") stay intact.
            printf '%s\t%s\n' "$opt" "$(_get_value "$opt")" >> "$STATE_FILE"
          done
        fi
        hyprctl --batch "\
          keyword animations:enabled 0 ; \
          keyword decoration:blur:enabled 0 ; \
          keyword decoration:shadow:enabled 0 ; \
          keyword decoration:rounding 0 ; \
          keyword general:gaps_in 0 ; \
          keyword general:gaps_out 0"
        _notify_waybar
      }

      _off() {
        # Restore saved values point-wise (no reload). Preserve internal spaces
        # of multi-word values by reading only up to the first tab.
        if [ -f "$STATE_FILE" ]; then
          batch=""
          restore_ok=1
          while IFS=$'\t' read -r opt val; do
            [ -n "$opt" ] || continue
            if [ -z "$val" ]; then
              restore_ok=0
              break
            fi
            batch="$batch keyword $opt $val ;"
          done < "$STATE_FILE"
          if [ "$restore_ok" = 1 ] && [ -n "$batch" ]; then
            hyprctl --batch "''${batch% ;}"
            rm -f "$STATE_FILE"
            _notify_waybar
            return
          fi
        fi
        # Emergency fallback only: state missing or a value could not be read.
        # Full reload re-applies the declarative Hyprland config from disk.
        hyprctl reload
        rm -f "$STATE_FILE"
        _notify_waybar
      }

      cmd="''${1:-toggle}"
      case "$cmd" in
        on) _on ;;
        off) _off ;;
        status) _status ;;
        toggle)
          if [ "$(_status)" = "on" ]; then _off; else _on; fi
          ;;
        *) echo "Usage: gaming-mode {toggle|on|off|status}" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  package = gamingMode;
}
