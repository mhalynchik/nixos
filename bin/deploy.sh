#!/usr/bin/env bash
set -euo pipefail

SOURCE="${NIXOS_CONFIG_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET="${NIXOS_CONFIG_TARGET:-/etc/nixos}"

if [[ ! -d "$SOURCE" ]]; then
  echo "Ошибка: source repo не найден: $SOURCE" >&2
  exit 1
fi

mkdir -p "$TARGET"

rsync -a --delete --no-owner --no-group \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='vars.nix' \
  --exclude='hardware-configuration.nix' \
  --exclude='result' \
  --exclude='result-*' \
  --exclude='.deploy-version' \
  "$SOURCE/" "$TARGET/"

if command -v git >/dev/null 2>&1 && git -C "$SOURCE" rev-parse HEAD >/dev/null 2>&1; then
  git -C "$SOURCE" rev-parse HEAD > "$TARGET/.deploy-version"
fi

echo "Deploy: $SOURCE -> $TARGET"
