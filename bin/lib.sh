#!/usr/bin/env bash

# Flake в git-репо видит только закоммиченные файлы.
commit_local_config_in_git() {
  local target="${1:?}"
  local message="${2:-config: wizard update}"

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
