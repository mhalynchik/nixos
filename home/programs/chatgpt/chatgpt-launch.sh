#!/usr/bin/env bash
# Copy bundled plugins with writable mode, then bind-mount over the nix store
# path. Electron fs.cp keeps store 0444 bits; writeFile/rmdir then EACCES.
set -euo pipefail

STORE_PLUGINS='@plugins@'
ELECTRON='@electron@'
BWRAP='@bwrap@'

cache="${XDG_CACHE_HOME:-$HOME/.cache}/chatgpt/openai-bundled"
codex_home="${CODEX_HOME:-$HOME/.codex}"

_sync_tree() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  if [[ ! -f "$dest/.store-src" ]] || [[ "$(cat "$dest/.store-src")" != "$STORE_PLUGINS" ]]; then
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a --no-preserve=mode "$STORE_PLUGINS/." "$dest/"
    chmod -R u+rwX "$dest"
    printf '%s\n' "$STORE_PLUGINS" > "$dest/.store-src"
  fi
}

_sync_tree "$cache"
_sync_tree "$codex_home/.tmp/bundled-marketplaces/openai-bundled"
_sync_tree "$codex_home/plugins/cache/openai-bundled"

if [[ -d "$codex_home/.tmp/bundled-marketplaces" ]]; then
  chmod -R u+rwX "$codex_home/.tmp/bundled-marketplaces" || true
  find "$codex_home/.tmp/bundled-marketplaces" -mindepth 1 -maxdepth 1 \
    -type d -name 'openai-bundled.staging-*' -exec rm -rf {} +
fi

# shellcheck disable=SC2086
if "$BWRAP" --die-with-parent --dev-bind / / --bind "$cache" "$STORE_PLUGINS" -- true; then
  exec "$BWRAP" --die-with-parent --dev-bind / / --bind "$cache" "$STORE_PLUGINS" -- \
    "$ELECTRON" ${CHATGPT_ELECTRON_FLAGS:-} "$@"
fi

exec "$ELECTRON" ${CHATGPT_ELECTRON_FLAGS:-} "$@"
