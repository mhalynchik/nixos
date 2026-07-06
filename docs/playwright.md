# Playwright MCP на NixOS

Инструкция по настройке Playwright как MCP сервера для расширений VS Code/Cursor (Continue, Cline и др.) на NixOS.

## Проблема

Стандартный подход установки Playwright через `npx` не работает на NixOS:

```bash
npx playwright install firefox
# Ошибка: Host system is missing dependencies to run browsers
# Missing libraries: libstdc++.so.6, libX11.so.6, libgtk-3.so.0 ...
```

Это происходит потому, что NixOS не следует стандартной FHS (Filesystem Hierarchy Standard), и библиотеки находятся не там, где их ожидают pre-built бинарники.

## Решение

### 1. Включить nix-ld в configuration.nix

`nix-ld` предоставляет необходимые библиотеки для динамически слинкованных бинарников:

```nix
# В configuration.nix
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
    # Core libraries
    stdenv.cc.cc.lib
    zlib
    glib

    # X11/XCB libraries
    xorg.libX11
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXcomposite
    xorg.libxcb
    xorg.libxshmfence

    # GTK/GDK
    gtk3
    gdk-pixbuf
    pango
    cairo
    atk

    # Audio
    alsa-lib
    pulseaudio

    # Fonts/Rendering
    fontconfig
    freetype

    # Other dependencies
    dbus
    nss
    nspr
    expat
    cups
    libdrm
    mesa
    libxkbcommon
    at-spi2-atk
    at-spi2-core
  ];
};
```

Применить изменения:

```bash
sudo nixos-rebuild switch --flake /etc/nixos# --impure
```

### 2. Создать wrapper-скрипт

Создайте файл `~/.local/bin/playwright-mcp`:

```bash
#!/usr/bin/env bash
# Playwright MCP wrapper for NixOS

set -e

# Ensure PATH includes user profile and system binaries
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

# nix-ld environment - CRITICAL for browser execution
export NIX_LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib"
export NIX_LD="/run/current-system/sw/share/nix-ld/lib/ld.so"

# Also set LD_LIBRARY_PATH as fallback - IMPORTANT for child processes (browser)
export LD_LIBRARY_PATH="${NIX_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH:-}"

# Skip host validation
export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1

# Ensure HOME is set (needed for browser cache)
export HOME="${HOME:-/home/$USER}"

# XDG directories
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Wayland/Display settings (if running in graphical session)
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}"
export DISPLAY="${DISPLAY:-:0}"

# Run the MCP server
exec npx "@playwright/mcp@latest" "$@"
```

Сделать исполняемым:

```bash
chmod +x ~/.local/bin/playwright-mcp
```

### 3. Установить браузер

```bash
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 npx playwright install firefox
```

### 4. Настроить MCP в Continue

В конфигурации Continue (`~/.continue/config.yaml` или настройки расширения):

```yaml
mcpServers:
  - name: Browser search
    command: /home/ВАШ_ЮЗЕРНЕЙМ/.local/bin/playwright-mcp
    args:
      - "--browser"
      - "firefox"
```

**Важно:** Используйте полный путь к скрипту!

### 5. Перезапустить IDE

После изменения конфигурации перезапустите VS Code/Cursor полностью.

## Проверка работоспособности

Проверить MCP сервер вручную:

```bash
# Тест инициализации
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ~/.local/bin/playwright-mcp --browser firefox

# Ожидаемый ответ:
# {"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"Playwright","version":"..."}},"jsonrpc":"2.0","id":1}
```

## Альтернатива: Playwright из nixpkgs

Для использования Playwright напрямую (не через MCP), можно использовать версию из nixpkgs:

```bash
# Временно через nix-shell
nix-shell -p playwright-test --run "playwright test"

# Или добавить в environment.systemPackages
environment.systemPackages = with pkgs; [
  playwright-test
];
```

## Правила для Continue (улучшение работы с инструментами)

Для улучшения работы AI моделей с Playwright MCP создайте правила в `~/.continue/rules/`:

### ~/.continue/rules/playwright.md

```markdown
# Playwright Browser MCP Usage Rules

## Golden Rules

1. **SNAPSHOT FIRST** — Always `browser_snapshot` before any interaction
2. **USE REFS** — Click/type using `ref` from snapshot, never guess selectors
3. **WAIT FOR CHANGES** — Use `browser_wait_for` after actions that change page

## JavaScript Evaluation (`browser_evaluate`)

### CRITICAL: NodeList is NOT an Array!

// ❌ WRONG — will fail
document.querySelectorAll('a').map(a => a.href)

// ✅ CORRECT — convert to array first
Array.from(document.querySelectorAll('a')).map(a => a.href)

## File Upload Sequence

`browser_file_upload` requires OPEN file dialog:
1. browser_snapshot → find file input element
2. browser_click → click on file input
3. browser_file_upload → NOW you can upload files

## Saving Content to Files

1. Use browser_evaluate or browser_snapshot to get data
2. Use WRITE tool (not edit) to save
3. Use ABSOLUTE path: /home/USERNAME/data.txt
```

### ~/.continue/rules/file-operations.md

```markdown
# File Operations Rules

## Creating vs Editing Files

1. Before editing a file, CHECK if it exists
2. If file doesn't exist — CREATE it, don't try to edit
3. Use absolute paths when possible

## Error Handling

If you see "file does not exist" error:
- DON'T retry with edit
- CREATE the file instead using write/create tool
```

### ~/.continue/rules/general.md

```markdown
# General Rules

## Language
- Respond in Russian (Русский)

## Error Recovery
When a tool fails:
1. Read the error message carefully
2. Understand WHY it failed
3. Choose correct alternative
4. Don't repeat the same failing action
```

## Рекомендации по моделям

Для работы с MCP инструментами рекомендуются модели **70B+ параметров**. Маленькие модели (7B-14B) часто делают ошибки:
- Путают `create` и `edit`
- Забывают конвертировать `NodeList` в массив
- Не следуют правильной последовательности действий

Если используете маленькие модели:
- Давайте пошаговые инструкции
- Явно указывайте какой инструмент использовать
- Корректируйте ошибки прямым указанием

## Устранение неполадок

### Ошибка "Connection closed" в Continue

1. Убедитесь, что указан **полный путь** к скрипту
2. Перезапустите IDE полностью (не просто reload window)
3. Проверьте логи: `Ctrl+Shift+P` → "Continue: View Logs"

### Браузер не запускается

Проверьте, что браузер установлен:

```bash
ls ~/.cache/ms-playwright/
```

Переустановите при необходимости:

```bash
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 npx playwright install firefox
```

### Несовместимость версий

Если `@playwright/mcp@latest` требует другую версию браузеров, переустановите их:

```bash
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 npx playwright install
```

