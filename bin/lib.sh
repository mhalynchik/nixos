#!/usr/bin/env bash
# Локальные файлы /etc/nixos в git: flake видит только tracked файлы.
track_local_config_in_git() {
  local target="${1:?}"
  if [[ ! -d "$target/.git" ]]; then
    return 0
  fi
  if [[ ! -f "$target/.gitignore" && -f "$target/hosts/gitignore.local.example" ]]; then
    cp "$target/hosts/gitignore.local.example" "$target/.gitignore"
  fi
  for f in vars.nix hardware-configuration.nix; do
    if [[ -f "$target/$f" ]]; then
      git -C "$target" add -f "$f" 2>/dev/null || true
    fi
  done
}
