{ config, pkgs, vars, colors, configDir, ... }:

{
  home-manager.users.${vars.username} = {
    # Starship prompt - красивый и быстрый prompt
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        # Формат prompt
        format = ''
          [╭─](${colors.colors.accent}) $os$username$hostname$directory$git_branch$git_status$cmd_duration
          [╰─](${colors.colors.accent})$character
        '';

        # Правая часть prompt
        right_format = "$nix_shell$docker_context$kubernetes";

        # Добавляем пустую строку между командами
        add_newline = true;

        # Символ prompt
        character = {
          success_symbol = "[❯](bold ${colors.colors.green})";
          error_symbol = "[❯](bold ${colors.colors.red})";
          vimcmd_symbol = "[❮](bold ${colors.colors.accent})";
        };

        # OS иконка
        os = {
          disabled = false;
          style = "bold ${colors.colors.accent}";
          symbols = {
            NixOS = " ";
          };
        };

        # Username
        username = {
          show_always = false;
          style_user = "bold ${colors.colors.mauve}";
          style_root = "bold ${colors.colors.red}";
          format = "[$user]($style) ";
        };

        # Hostname (только для SSH)
        hostname = {
          ssh_only = true;
          style = "bold ${colors.colors.yellow}";
          format = "@ [$hostname]($style) ";
        };

        # Директория
        directory = {
          style = "bold ${colors.colors.blue}";
          format = "[$path]($style)[$read_only]($read_only_style) ";
          truncation_length = 3;
          truncation_symbol = "…/";
          read_only = " 󰌾";
          read_only_style = "bold ${colors.colors.red}";
          home_symbol = "~";
        };

        # Git branch
        git_branch = {
          symbol = " ";
          style = "bold ${colors.colors.lavender}";
          format = "on [$symbol$branch]($style) ";
        };

        # Git status
        git_status = {
          style = "bold ${colors.colors.peach}";
          format = "([$all_status$ahead_behind]($style))";
          conflicted = "⚡";
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          untracked = "?\${count}";
          stashed = "📦";
          modified = "!\${count}";
          staged = "+\${count}";
          renamed = "»\${count}";
          deleted = "✘\${count}";
        };

        # Время выполнения команды
        cmd_duration = {
          min_time = 2000;
          style = "bold ${colors.colors.yellow}";
          format = "took [$duration]($style) ";
        };

        # Nix shell
        nix_shell = {
          disabled = false;
          symbol = " ";
          style = "bold ${colors.colors.blue}";
          format = "[$symbol$state]($style) ";
          impure_msg = "";
          pure_msg = "pure";
        };

        # Docker
        docker_context = {
          symbol = " ";
          style = "bold ${colors.colors.blue}";
          format = "[$symbol$context]($style) ";
          only_with_files = true;
        };

        # Kubernetes
        kubernetes = {
          disabled = false;
          symbol = "☸ ";
          style = "bold ${colors.colors.blue}";
          format = "[$symbol$context( \\($namespace\\))]($style) ";
        };
      };
    };

    programs.zsh = {
      enable = true;

      # .zshenv — читается ВСЕМИ zsh (включая non-interactive из cursor-agent).
      # Минимальный invariant: $HOME/.local/bin есть в PATH. БЕЗ переставления
      # порядка — иначе ломаются mv/uname/grep из /tmp/.mount_cursor*/usr/bin/,
      # на которые опирается compinit и shell-integration.
      envExtra = ''
        case ":$PATH:" in
          *":$HOME/.local/bin:"*) ;;
          *) export PATH="$HOME/.local/bin:$PATH" ;;
        esac
      '';

      oh-my-zsh = {
        enable = true;
        theme = "";  # Отключаем oh-my-zsh тему, используем Starship
        plugins = [
          "git"
          "docker"
          "kubectl"
          "sudo"
          "history"
          "dirhistory"
        ];
      };

      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;

      shellAliases = {
        # System
        ll = "ls -la";
        la = "ls -A";
        l = "ls -CF";
        ".." = "cd ..";
        "..." = "cd ../..";

        # Override oh-my-zsh grep alias (removes --exclude-dir which breaks BusyBox grep in k8s)
        grep = "grep --color=auto";

        # NixOS (configDir auto-detected from flake location)
        nrs = "sudo nixos-rebuild switch --flake '${configDir}#' --impure";
        nrt = "sudo nixos-rebuild test --flake '${configDir}#' --impure";
        nfu = "nix flake update ${configDir}";
        ngc = "sudo nix-collect-garbage -d";

        # Git
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gl = "git pull";
        gd = "git diff";
        gco = "git checkout";
        gb = "git branch";
        lg = "lazygit";

        # Docker
        dc = "docker compose";
        dps = "docker ps";
        dimg = "docker images";
        dex = "docker exec -it";
        dlogs = "docker logs -f";
        ld = "lazydocker";

        # Kubernetes
        k = "kubectl";
        kgs = "kubectl get services";
        kgd = "kubectl get deployments";
        kctx = "kubectx";
        # kns, kgp, kd, kl, ke, k9 - определены как функции в initContent

        # Editors
        v = "nvim";
        vim = "nvim";

        # Utils
        # cat = "bat";
        top = "btop";
        fetch = "fastfetch";  # System info
        ff = "fastfetch";

        # Hyprland
        hc = "hyprctl";

        # Quick edit configs (configDir auto-detected from flake location)
        ehy = "nvim ${configDir}/home/programs/hypr/default.nix";
        ewb = "nvim ${configDir}/home/programs/waybar/default.nix";
        ezsh = "nvim ${configDir}/home/programs/zsh/default.nix";
        evars = "nvim ${configDir}/vars.nix";
      };

      initContent = ''
        # Custom prompt character
        REFINED_CHAR_SYMBOL="⚡"

        # PATH-фильтр для /tmp/.mount_cursor* живёт в envExtra (.zshenv),
        # чтобы покрывать и non-interactive zsh из cursor-agent.

        # Path additions
        export PATH=$HOME/bin:$HOME/.local/bin:$PATH
        export PATH=$HOME/scripts:$PATH

        # NVM support (if installed)
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        # Rofi scripts
        export PATH=$HOME/.config/rofi/scripts:$PATH

        # Better history
        HISTSIZE=10000
        SAVEHIST=10000
        setopt SHARE_HISTORY
        setopt HIST_IGNORE_DUPS
        setopt HIST_IGNORE_SPACE

        # Enable vi mode
        # bindkey -v

        # Fast directory switching
        setopt AUTO_CD
        setopt AUTO_PUSHD
        setopt PUSHD_IGNORE_DUPS

        # Case insensitive completion
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

        # ═══════════════════════════════════════════════════════════════
        # Kubernetes helper functions (для кластеров с ограниченными правами)
        # ═══════════════════════════════════════════════════════════════

        # Убираем конфликтующие алиасы из oh-my-zsh kubectl плагина
        unalias kl 2>/dev/null
        unalias kd 2>/dev/null
        unalias ke 2>/dev/null
        unalias kgp 2>/dev/null

        # Namespace'ы привязаны к контексту. Формат: "context:ns1,ns2,ns3"
        # Редактируй этот файл: ~/.kube/my-namespaces
        # Пример содержимого:
        #   staging:controller,staging,default
        #   prod-cluster:app-prod,monitoring
        KUBE_NS_FILE="$HOME/.kube/my-namespaces"

        # Получить namespace'ы для текущего контекста (возвращает через пробел)
        _get_my_namespaces() {
          local ctx=$(kubectl config current-context 2>/dev/null)
          if [[ -f "$KUBE_NS_FILE" && -n "$ctx" ]]; then
            # Берём первую строку для контекста, заменяем запятые на пробелы
            # command grep - обходим алиас oh-my-zsh с --exclude-dir
            command grep "^$ctx:" "$KUBE_NS_FILE" 2>/dev/null | head -1 | cut -d: -f2 | tr ',' ' '
          fi
        }

        # Получить текущий namespace
        _get_current_ns() {
          kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null
        }

        # kns - переключить namespace БЕЗ проверки прав
        # Использование: kns <namespace> или kns (покажет список и текущий)
        kns() {
          if [[ -z "$1" ]]; then
            local ctx=$(kubectl config current-context 2>/dev/null)
            local current_ns=$(_get_current_ns)
            echo "Контекст: $ctx"
            echo "Текущий namespace: ''${current_ns:-<не установлен>}"
            local my_ns=$(_get_my_namespaces)
            if [[ -n "$my_ns" ]]; then
              echo "\nМои namespace'ы для этого контекста:"
              for ns in ''${(z)my_ns}; do
                if [[ "$ns" == "$current_ns" ]]; then
                  echo "  → $ns (текущий)"
                else
                  echo "  - $ns"
                fi
              done
            else
              echo "\nNamespace'ы не настроены для этого контекста."
              echo "Добавь в $KUBE_NS_FILE строку:"
              echo "  $ctx:namespace1,namespace2,namespace3"
            fi
          else
            kubectl config set-context --current --namespace="$1"
            echo "Namespace: $1"
          fi
        }

        # knsa - добавить namespace в список для текущего контекста
        knsa() {
          local ctx=$(kubectl config current-context 2>/dev/null)
          local ns="$1"
          if [[ -z "$ns" ]]; then
            echo "Использование: knsa <namespace>"
            return 1
          fi
          mkdir -p "$(dirname "$KUBE_NS_FILE")"
          touch "$KUBE_NS_FILE"

          local line=$(command grep "^$ctx:" "$KUBE_NS_FILE" 2>/dev/null | head -1)
          if [[ -n "$line" ]]; then
            local namespaces=$(echo "$line" | cut -d: -f2)
            # Проверяем, есть ли уже этот namespace (точное совпадение)
            if echo ",$namespaces," | command grep -q ",$ns,"; then
              echo "Namespace '$ns' уже есть в списке"
              return 0
            fi
            # Добавляем в конец
            local new_line="$ctx:$namespaces,$ns"
            # Удаляем старую строку и добавляем новую
            command grep -v "^$ctx:" "$KUBE_NS_FILE" > "$KUBE_NS_FILE.tmp"
            echo "$new_line" >> "$KUBE_NS_FILE.tmp"
            mv "$KUBE_NS_FILE.tmp" "$KUBE_NS_FILE"
          else
            # Новый контекст
            echo "$ctx:$ns" >> "$KUBE_NS_FILE"
          fi
          echo "Добавлен namespace '$ns' для контекста '$ctx'"
        }

        # knsr - удалить namespace из списка для текущего контекста
        knsr() {
          local ctx=$(kubectl config current-context 2>/dev/null)
          local ns="$1"
          if [[ -z "$ns" ]]; then
            echo "Использование: knsr <namespace>"
            return 1
          fi
          if [[ ! -f "$KUBE_NS_FILE" ]]; then
            echo "Файл $KUBE_NS_FILE не существует"
            return 1
          fi

          local line=$(command grep "^$ctx:" "$KUBE_NS_FILE" 2>/dev/null | head -1)
          if [[ -z "$line" ]]; then
            echo "Контекст '$ctx' не найден в $KUBE_NS_FILE"
            return 1
          fi

          local namespaces=$(echo "$line" | cut -d: -f2)
          # Проверяем, есть ли этот namespace
          if ! echo ",$namespaces," | command grep -q ",$ns,"; then
            echo "Namespace '$ns' не найден в списке"
            return 1
          fi

          # Удаляем namespace из списка
          local new_namespaces=$(echo "$namespaces" | sed "s/,$ns,/,/g; s/^$ns,//; s/,$ns$//; s/^$ns$//")
          
          # Обновляем файл
          command grep -v "^$ctx:" "$KUBE_NS_FILE" > "$KUBE_NS_FILE.tmp"
          if [[ -n "$new_namespaces" ]]; then
            echo "$ctx:$new_namespaces" >> "$KUBE_NS_FILE.tmp"
          fi
          mv "$KUBE_NS_FILE.tmp" "$KUBE_NS_FILE"
          echo "Удалён namespace '$ns' для контекста '$ctx'"
        }

        # Автодополнение для kns и knsr
        _kns_completion() {
          local my_ns=$(_get_my_namespaces)
          if [[ -n "$my_ns" ]]; then
            compadd ''${(z)my_ns}
          fi
        }
        compdef _kns_completion kns
        compdef _kns_completion knsr

        # Автодополнение для подов (кэшируется на 30 сек)
        _kubectl_pod_completion() {
          local ns=$(_get_current_ns)
          local cache_file="/tmp/.kube-pods-cache-''${ns:-default}"
          local cache_age=30

          # Проверяем кэш
          if [[ -f "$cache_file" ]]; then
            local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
            if [[ $file_age -lt $cache_age ]]; then
              compadd $(cat "$cache_file")
              return
            fi
          fi

          # Обновляем кэш
          local pods=$(kubectl get pods -n "''${ns:-default}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
          if [[ -n "$pods" ]]; then
            echo "$pods" > "$cache_file"
            compadd ''${(z)pods}
          fi
        }

        # kd - describe pod
        kd() {
          local ns=$(_get_current_ns)
          kubectl describe pod "$1" -n "''${ns:-default}"
        }
        compdef _kubectl_pod_completion kd

        # kl - logs (follow)
        # Использование: kl <pod> [-c container]
        kl() {
          local ns=$(_get_current_ns)
          kubectl logs -f "$@" -n "''${ns:-default}"
        }
        compdef _kubectl_pod_completion kl

        # ke - exec в под
        # Использование: ke <pod> [command]
        ke() {
          local pod="$1"
          shift
          local cmd="''${@:-/bin/sh}"
          local ns=$(_get_current_ns)
          kubectl exec -it "$pod" -n "''${ns:-default}" -- $cmd
        }
        compdef _kubectl_pod_completion ke

        # kgp - get pods
        kgp() {
          local ns=$(_get_current_ns)
          kubectl get pods -n "''${ns:-default}" -o wide
        }

        # k9 - быстрый запуск k9s в текущем namespace
        k9() {
          local ns="''${1:-$(_get_current_ns)}"
          k9s -n "''${ns:-default}"
        }
        compdef _kns_completion k9
      '';
    };
  };

  # Set zsh as default shell for user
  users.users.${vars.username}.shell = pkgs.zsh;
  programs.zsh.enable = true;
}
