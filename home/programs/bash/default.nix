{ config, vars, ... }:

{
  home-manager.users.${vars.username} = {
    programs.bash = {
      enable = true;

      # Минимальный invariant: $HOME/.local/bin есть в PATH.
      # Без переставления — AppImage Cursor добавляет в начало /tmp/.mount_*/usr/bin/,
      # и compinit/shell-integration рассчитывают на эти helpers.
      initExtra = ''
        case ":$PATH:" in
          *":$HOME/.local/bin:"*) ;;
          *) export PATH="$HOME/.local/bin:$PATH" ;;
        esac
      '';
    };
  };
}
