#!/usr/bin/env bash

# Flake в git-репо видит только закоммиченные файлы.
ensure_target_git() {
  local target="${1:?}"
  if [[ -d "$target/.git" ]]; then
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "Предупреждение: git не найден, vars.nix может быть невидим для flake" >&2
    return 0
  fi
  echo "Инициализация git в $target (нужно для flake)"
  git -C "$target" init -b main
  if [[ ! -f "$target/.gitignore" && -f "$target/hosts/gitignore.local.example" ]]; then
    cp "$target/hosts/gitignore.local.example" "$target/.gitignore"
  fi
}

commit_local_config_in_git() {
  local target="${1:?}"
  local message="${2:-config: wizard update}"

  ensure_target_git "$target"

  if [[ ! -d "$target/.git" ]]; then
    return 0
  fi

  if [[ ! -f "$target/.gitignore" && -f "$target/hosts/gitignore.local.example" ]]; then
    cp "$target/hosts/gitignore.local.example" "$target/.gitignore"
  fi

  git -C "$target" add -A

  for f in vars.nix hardware-configuration.nix; do
    if [[ -f "$target/$f" ]]; then
      git -C "$target" add -f "$f" 2>/dev/null || true
    fi
  done

  if git -C "$target" diff --cached --quiet; then
    echo "Нет изменений для коммита в $target"
    return 0
  fi

  if ! git -C "$target" config user.email >/dev/null 2>&1; then
    git -C "$target" config user.email "nixos-config@local"
  fi
  if ! git -C "$target" config user.name >/dev/null 2>&1; then
    git -C "$target" config user.name "nixos-config"
  fi

  git -C "$target" commit -m "$message"
  echo "Коммит в $target: $message"
}

commit_message_after_deploy() {
  local target="${1:?}"
  local version_file="$target/.deploy-version"
  if [[ -f "$version_file" ]]; then
    local rev
    rev="$(tr -d '[:space:]' < "$version_file")"
    echo "deploy: sync from source (${rev:0:12})"
  else
    echo "deploy: sync from source"
  fi
}

rebuild_flake() {
  local target="${1:?}"
  local action="${2:?}"
  sudo nixos-rebuild "$action" --flake "$target#default" --impure
}

install_flake() {
  local target="${1:?}"
  if ! mountpoint -q /mnt 2>/dev/null; then
    echo "Ошибка: /mnt не смонтирован. Сначала разметьте диск и смонтируйте корень в /mnt." >&2
    echo "Пример: mount /dev/disk/by-label/nixos /mnt && mount /dev/disk/by-label-boot /mnt/boot" >&2
    exit 1
  fi
  echo "Установка на /mnt через nixos-install..."
  sudo nixos-install --flake "$target#default" --impure
}

prompt_setup_mode() {
  echo
  echo "Режим setup:"
  echo "  1) Установка с ISO (nixos-install → /mnt)"
  echo "  2) Rebuild установленной системы (nixos-rebuild)"
  read -r -p "Выбор [2]: " mode_choice
  case "${mode_choice:-2}" in
    1) echo "install" ;;
    *) echo "rebuild" ;;
  esac
}

hint_install_iso() {
  echo
  echo "=== Установка с ISO ==="
  echo "Live-система с флешки. nixos-install запишет конфиг на диск (/mnt)."
  echo "Перед продолжением:"
  echo "  1. Разметить диск (cfdisk/fdisk)"
  echo "  2. Смонтировать корень в /mnt (и /mnt/boot для EFI)"
  echo "  3. При нехватке RAM — включить swap (см. docs/install-iso.md)"
  echo
  read -r -p "Диск смонтирован в /mnt? [y/N]: " mnt_ready
  if [[ ! "${mnt_ready:-N}" =~ ^[Yy]$ ]]; then
    echo "Смонтируйте /mnt и запустите setup снова." >&2
    exit 1
  fi
  if ! mountpoint -q /mnt; then
    echo "Ошибка: /mnt не является точкой монтирования." >&2
    exit 1
  fi
}

