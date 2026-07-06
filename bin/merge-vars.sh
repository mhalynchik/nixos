#!/usr/bin/env bash
set -euo pipefail

SOURCE="${NIXOS_CONFIG_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET="${NIXOS_CONFIG_TARGET:-/etc/nixos}"
EXAMPLE="$SOURCE/vars.nix.example"
VARS="$TARGET/vars.nix"

if [[ ! -f "$EXAMPLE" ]]; then
  echo "vars.nix.example не найден" >&2
  exit 1
fi

if [[ ! -f "$VARS" ]]; then
  echo "vars.nix не существует, merge не нужен"
  exit 0
fi

echo "Merge vars.nix: добавляем только новые ключи из example"
echo "Существующие значения не изменяются."
echo "Полный пересоздание: ./bin/wizard-vars.sh $VARS"

missing=()
for key in features programs theme username homeDirectory gitUsername gitEmail hostname timezone locale hashedPassword monitor terminal browser deepcoolScript location vpn gamemodeGpuDevice stateVersion agsPopupTimeout telegram discord; do
  if ! grep -q "$key" "$VARS"; then
    missing+=("$key")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "Новых ключей не найдено"
  exit 0
fi

echo "Отсутствующие ключи: ${missing[*]}"
echo "Добавьте их вручную из $EXAMPLE или запустите wizard-vars.sh для пересоздания"
exit 0
