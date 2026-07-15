# NixOS Hyprland Configuration

Модульная NixOS-конфигурация с Hyprland, Home Manager и выбором модулей через `vars.nix`.

## Архитектура

```
~/nixos-config/          git + remote (GitHub), без vars.nix
  flake.nix, modules/, bin/, vars.nix.example
        |
        |  bin/deploy.sh (rsync)
        v
/etc/nixos/              deploy target, локальный git (без remote)
  vars.nix               локально tracked (не в GitHub)
  hardware-configuration.nix
        |
        v
  nixos-rebuild switch --flake /etc/nixos# --impure
```

**Две директории:**
- `~/nixos-config` — общий конфиг, синхронизация с GitHub, `vars.nix` в `.gitignore`
- `/etc/nixos` — рабочая копия на машине, может иметь **локальный git** для своих коммитов

**Flake и vars.nix:** если `/etc/nixos` — git repo, flake видит только **закоммиченные** файлы. Wizard инициализирует git в `/etc/nixos` (если нет), затем `git add` + `git commit`. В GitHub секреты не попадают — remote только у `~/nixos-config`.

**Сборка из `~/nixos-config`:** `vars.nix` и `hardware-configuration.nix` в `.gitignore`, поэтому для eval/build укажите каталог с этими файлами:

```bash
NIXOS_CONFIG_DIR=/etc/nixos nix build ~/nixos-config#nixosConfigurations.default.config.system.build.toplevel --impure
```

`flake.nix` читает `${configDir}/vars.nix`; `configuration.nix` импортирует `${configDir}/hardware-configuration.nix`.

## Первый запуск

### Уже установленный NixOS (rebuild)

```bash
git clone https://github.com/mhalynchik/nix-config.git ~/nixos-config
cd ~/nixos-config
./bin/setup
# Выбор: 2) Rebuild
```

### Установка с ISO (live)

См. [docs/install-iso.md](docs/install-iso.md). Кратко:

```bash
# разметка + mount /mnt
git clone https://github.com/mhalynchik/nix-config.git ~/nixos-config
cd ~/nixos-config
./bin/setup
# Выбор: 1) Установка с ISO → nixos-install
```

Wizard:
1. Deploy конфига в `/etc/nixos` или `/mnt/etc/nixos`
2. Создаёт `vars.nix` (интерактивно)
3. Генерирует `hardware-configuration.nix`
4. Коммитит изменения
5. **Rebuild:** `nixos-rebuild switch` или **ISO:** `nixos-install`

## Обновление

Подтянуть upstream (по желанию, вручную):

```bash
cd ~/nixos-config
git pull
```

Применить конфиг в систему:

```bash
~/nixos-config/bin/update
```

`bin/update` **не делает** `git pull`. Только:
1. Deploy source → `/etc/nixos`
2. Спрашивает про `vars.nix` (оставить / merge / пересоздать)
3. Коммитит изменения в `/etc/nixos`
4. `nixos-rebuild switch`

Можно менять `vars.nix` и модули локально и запускать `update` без pull.

## Переменные окружения

| Переменная | По умолчанию | Назначение |
|------------|--------------|------------|
| `NIXOS_CONFIG_SOURCE` | каталог `bin/..` | Путь к git repo |
| `NIXOS_CONFIG_TARGET` | `/etc/nixos` | Deploy target |
| `NIXOS_CONFIG_DIR` | каталог flake | Путь к `vars.nix` и `hardware-configuration.nix` (см. ниже) |
| `NIXOS_CONFIG_REPO` | — | URL для clone в setup |

## Флаги модулей

### `features.*` (система)

| Флаг | Описание |
|------|----------|
| `docker` | Docker + docker-compose |
| `k8s` | kubectl, helm, k9s |
| `gaming` | Steam, Wine, gamemode |
| `nvidia` | NVIDIA drivers |
| `vpn` | OpenVPN + WireGuard |
| `flatpak` | Flatpak + PortProton |
| `devTools` | dotnet, python, postman, unityhub |
| `openWebui` | Open WebUI service |
| `deepcool` | DeepCool LCD (нужен `deepcoolScript`) |
| `maxSandbox` | VM sandbox для MAX |
| `maxBypassVpn` | Трафик VM в обход VPN |
| `sshPasswordAuth` | SSH по паролю |

### `programs.*` (home)

| Флаг | Описание |
|------|----------|
| `ags`, `spotify`, `telegram`, `discord`, `planify` | Приложения |
| `cursor`, `vscode`, `zed`, `lunarvim` | Редакторы |
| `steam` | Steam theme module |

Также: `browser` (`floorp` / `librewolf`), `terminal` (`kitty`), `theme` (см. раздел [Темы](#темы)).

Обои (каталоги относительно `$HOME`): `staticWallpapersDir`, `animatedWallpapersDir`, `defaultWallpaper`.

Шаблон: [`vars.nix.example`](vars.nix.example)

## Темы

`vars.theme` — единый selector. Переключение темы = смена `vars.theme` + rebuild.
Runtime-переключателя, редактирующего файлы Home Manager, нет.

Три уровня поддержки:

1. **Builtin themes** (`catppuccin`, `crimson`)
   Ручные палитры в `home/themes/palettes/`. Полный контроль, без внешних зависимостей.

2. **Curated declarative Gallery adapters** (`catppuccin-mocha`)
   Одна закреплённая по commit тема HyDE Gallery (flake input `hyde-theme-catppuccin-mocha`).
   Адаптер `home/themes/gallery/adapter.nix` парсит только allowlisted цветовые поля
   (`kitty.theme`), валидирует их как 6-значный hex и отдаёт тот же публичный интерфейс
   `colors` (base16, colors, hyprland, waybar). GTK/icon-архивы распаковываются в
   read-only Nix derivations (при активной теме GTK/icon реально выбираются: `gtk.theme`,
   `gtk.iconTheme`, системный `GTK_THEME`, а Stylix GTK target отключается). Обои
   подключаются к wallpaper domain как store-assets. `~/.config/hyde` не создаётся.

   > **Лицензии не проверены.** В pinned commit нет файла LICENSE, а GTK/icon-архивы не
   > содержат лицензий. Лицензия темы, архивов и обоев **не подтверждена** (не считать
   > GPL-3.0 только потому, что основной HyDE — GPL). Не распространяйте эти ассеты без
   > самостоятельной проверки лицензий. Детали: `home/themes/gallery/NOTICE`.

3. **Неподдерживаемые runtime HyDE-фичи** (намеренно не реализованы)
   `hydectl` switching, `hyde-shell`, `wallbash` (runtime-извлечение цветов),
   `theme.patch.sh`, mutable GTK/Qt patching. Они правят `~/.config` во время runtime и
   конфликтуют с Home Manager. Заявляется поддержка только перечисленных выше adapters,
   а не всей Gallery.

Неизвестный `vars.theme` завершает eval ошибкой со списком поддерживаемых тем.
Собственные layout Waybar / Hyprland / Rofi / AGS сохраняются при любой теме — Gallery
даёт только палитру и ассеты, не перезаписывает конфиги.

## HyDE-стиль и утилиты (Waybar / Hyprland)

Визуал Catppuccin Mocha (HyDE-like): прозрачный Waybar с тремя «островами», rounding 14px, mauve-акцент. Палитра `crimson` не менялась — layout общий.

### Waybar (systemd)

Waybar управляется **systemd user service** (`waybar.service`, target `graphical-session.target`).
При `nixos-rebuild switch` Home Manager перезапускает сервис через **sd-switch** по
`X-Restart-Triggers` (новая тема применяется без релогина).

| Бинд | Действие |
|------|----------|
| `SUPER B` | Скрыть/показать Waybar (`waybar-toggle` → `SIGUSR1`, без stop/start) |
| `SUPER SHIFT B` | Перезапуск Waybar (`waybar-restart` → `reset-failed` + `restart`) |

`SUPER B` шлёт Waybar встроенный `SIGUSR1` (toggle видимости), не трогая unit — поэтому
частые нажатия больше не упираются в systemd start-limit и Waybar не «пропадает».
`waybar-watcher` и ручной `exec-once waybar` удалены — один экземпляр через systemd.

### AGS guard (`programs.ags`)

| `programs.ags` | Запуск | Клики Waybar (audio / BT / network) |
|----------------|--------|-------------------------------------|
| `true` | systemd `ags.service` | AGS popups |
| `false` | без AGS | `pavucontrol`, `blueman-manager`, `nm-connection-editor` |

AGS больше не в `exec-once`. Сервис имеет `X-Restart-Triggers` на `config.js` и `style.css`;
sd-switch перезапускает AGS при смене темы/rebuild.

Waybar `network` и `bluetooth` — нативные модули (реальный статус adapter/соединения),
клик открывает AGS-popup или соответствующий редактор. `custom/stats` при `ags = false`
запускает `btop` в терминале (fallback вместо мёртвой кнопки).

### SwayNC (systemd)

`swaync` управляется `services.swaync` (systemd user service). Убран из `exec-once`;
sd-switch перезапускает при изменении конфига/CSS (юнит имеет `X-Restart-Triggers` на
`config.json` и `style.css`). **Переходное замечание:** старый `swaync`, запущенный
прежним `exec-once`, продолжает жить в текущей сессии и удерживает старую тему
(окно уведомлений `SUPER N` остаётся crimson). Один релогин убирает stray-процесс,
дальше тема применяется автоматически при каждом rebuild.

### Dock и Lockscreen

- **nwg-dock** запускается без `-f` — ширина острова подстраивается под число значков
  приложений (раньше растягивался на весь экран на пустом воркспейсе).
- **Hyprlock:** точки пароля увеличены и контрастны (`dots_size 0.5`, светлый `font_color`
  на `surface1`). Индикатор раскладки перенесён в правый нижний угол, кратко `US`/`RU`
  со значком `⌨` (обновляется каждые 500 мс через `hyprctl devices`).

### Применение темы после rebuild

Waybar, SwayNC и AGS (если включён) перезапускаются через **sd-switch** при изменении
их конфигов (`systemd.user.startServices = true`). Ручной `home.activation restart` не
используется. Rebuild из TTY не падает; в активной графической сессии тема обновляется
сразу после switch.

### GTK / Qt (ограничения)

- **Builtin themes:** GTK через Stylix + Home Manager `gtk.theme` (глобальный `GTK_THEME`
  в session env не задаётся — он перекрывал бы Stylix).
- **Gallery themes:** `GTK_THEME` задаётся только при активной Gallery-теме.
- **prefer-dark:** `dconf color-scheme=prefer-dark` + GTK3/GTK4 `gtk-application-prefer-dark-theme=1`
  (Thunar и GTK-приложения). Electron под Wayland (`NIXOS_OZONE_WL=1` + `electron-flags.conf`)
  берёт тёмный `prefers-color-scheme` веб-контента из портала prefer-dark; **chrome самого
  приложения** (Cursor, VSCode, Discord, Spotify) задаётся внутри приложения, не отсюда.
- **Браузер (userChrome/base16):** Floorp и LibreWolf получают полностью theme-driven
  `userChrome.css`/`userContent.css`/`user.js` (палитра из `colors.colors`). Тема
  применяется автоматически при каждом rebuild через `home.activation` (idempotent-копия
  в `chrome/` профиля; вкладки/сессия не трогаются). После первого применения нужно
  перезапустить браузер. Ручной запуск: `apply-floorp-theme` / `apply-librewolf-theme`.
- **Иконки:** единый источник имени icon-темы — `colors.iconThemeName` (Gallery-иконки
  или `Papirus-Dark`). Его используют GTK (Waybar tray, nwg-dock, Thunar) и Rofi
  (`icon-theme`) — одинаковые значки во всех местах.
- **Qt:** дубликат `QT_QPA_PLATFORMTHEME=qt5ct` убран из Hyprland env (Stylix задаёт то же).
  Для проверки Qt использовать Qt-приложение (напр. `qt5ct`), не `pavucontrol` (GTK).

### SwayOSD

OSD для громкости, микрофона, яркости, CapsLock. Медиа-клавиши и scroll на модуле звука в Waybar. Для яркости пользователь в группе `video`.

### Rofi-утилиты

| Команда | Бинд | Описание |
|---------|------|----------|
| `emoji-picker` | `SUPER .` | Emoji → clipboard |
| `glyph-picker` | `SUPER ,` | Nerd Font glyph → clipboard |
| `rofi-websearch` | `SUPER ALT S` | Web search (префиксы из `websearch.lst`) |
| `rofi-calc` | `SUPER ALT C` | Калькулятор → clipboard |
| `cheatsheet` | `SUPER SHIFT K` | Шпаргалка биндов |
| `clipboard-picker` | `SUPER SHIFT V` | История clipboard (wl-clipboard 2.3 + cliphist) |

> **Внимание:** `cliphist` пишет содержимое буфера обмена (включая пароли и другие секреты) в историю на диск (`~/.cache/cliphist`). Очистка: `cliphist wipe`. Для чувствительных данных копируйте с учётом этого или очищайте историю.

`vars.browser` — только `floorp` или `librewolf` (иначе eval error).

Данные rofi: `home/programs/rofi/data/` (GPL-3.0, см. `NOTICE`).

### Wallpaper

| Команда | Бинд | Описание |
|---------|------|----------|
| `wallpaper-picker` | `SUPER SHIFT W` | Rofi-пикер статичных обоев |
| `wallpaper-animated` | `SUPER ALT W` | Случайное видео/GIF |
| `wallpaper-startup` | exec-once | animated → static → default |

Symlink: `~/.local/state/current-wallpaper`, `current-lock-wallpaper`.

Форматы: `staticWallpapersDir` — `jpg/jpeg/png/webp` (через swww); `animatedWallpapersDir` — `gif/mp4/webm/mkv` (через mpvpaper). **GIF работает только в `animatedWallpapersDir`** — в static-каталоге он игнорируется пикером/startup.

**Animated wallpaper = systemd user service** (`animated-wallpaper.service`). mpvpaper
запускается единственным экземпляром под управлением systemd (`Type=simple`, без `--fork`),
без shell-loop/timer/`pkill`. `wallpaper-set` при выборе animated атомарно обновляет symlink
`current-wallpaper`, один раз генерирует lock-frame и делает `systemctl --user restart
animated-wallpaper.service`; при выборе static — `systemctl --user stop` + swww.

> **Workaround RAM-leak mpvpaper:** сервис имеет `RuntimeMaxSec=45min` + `Restart=always`
> (`RestartSec=1s`), т.е. mpvpaper пересоздаётся каждые 45 минут, чтобы ограничить рост RSS.
> Периодический restart не меняет обои, не перегенерирует lock-frame и не шлёт notification.
> Если symlink отсутствует/повреждён/не animated-формат — runner выходит с кодом 3
> (`RestartPreventExitStatus=3`), restart-loop не возникает.

### Gaming profile (`features.gaming`)

Только при `features.gaming = true` (по умолчанию `false` в `vars.nix.example`). При `false` бинда и модуля Waybar нет.

`SUPER SHIFT G` — toggle gaming-mode (отключает blur/анимации Hyprland). Индикатор в Waybar.

### Прочие бинды (изменения)

| Бинд | Действие |
|------|----------|
| `SUPER CTRL S` | Screenshot в редактор (swappy) |
| `SUPER S` | Toggle scratchpad workspace |
| `SUPER SHIFT S` | Scratchpad round-trip: окно ↔ `special:magic` (возврат на активный workspace focused monitor) |

Полный список: SSOT `home/programs/hypr/keybinds.nix`, cheatsheet `SUPER SHIFT K`.

### Вне scope (отдельные планы)

- Runtime-темизация wallust (план C)
- polkit, hyprsunset, satty, rbw и др. (план D)

## Структура

```
modules/
  system/       ядро, desktop, audio, bluetooth, packages
  services/     docker, k8s, vpn, virt-manager
  home/         home-manager packages + imports
home/programs/  конфиги приложений
lib/            mkEnabledModules.nix
bin/            setup, update, deploy, wizard-vars
hosts/          hardware-configuration.nix.example
docs/           playwright, multi-monitor, max-sandbox-vm
```

## Rebuild вручную

```bash
sudo nixos-rebuild switch --flake /etc/nixos#default --impure
```

`#default` — явный attr flake. На ISO hostname часто `nixos`, поэтому flake также экспортирует `nixosConfigurations.nixos`.

`--impure` нужен для модуля Cursor (AppImage из `~/.local/opt/cursor/`).

## Документация

- [Установка с ISO](docs/install-iso.md)
- [Playwright на NixOS](docs/playwright.md)
- [MAX sandbox VM](docs/max-sandbox-vm.md)
- [Windows bootable USB](docs/windows-bootable-usb.md)

## Миграция

1. Скопировать repo: `cp -a /etc/nixos ~/nixos-config`
2. В `~/nixos-config`: настроить remote на GitHub, убедиться что `vars.nix` в `.gitignore`
3. `./bin/deploy.sh` — синхронизирует в `/etc/nixos`, **не трогает** `.git` в `/etc/nixos`
4. Локально в `/etc/nixos`: wizard коммитит `vars.nix`, `hardware-configuration.nix` и deploy-изменения

Локальный git в `/etc/nixos` остаётся для своих коммитов. Remote — только у `~/nixos-config`.
