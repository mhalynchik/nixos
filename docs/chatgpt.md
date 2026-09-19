# ChatGPT desktop

Флаг: `programs.chatgpt`. Официальный `.deb` `26.908.70816`, бинарь `chatgpt`.

nixpkgs `chatgpt` — только macOS. Здесь vendor Linux-пакет с `latest` URL и pinned hash. Лицензия unfree: имя в `allowUnfreePredicate` (`modules/system/core.nix`).

Nix не логинит аккаунт и не пишет ключи.

## Включение

В `vars.nix`:

```nix
programs.chatgpt = true;
```

Если ключа нет, `vars.nix.example` даёт `true` через merge. Затем `./bin/update`.

```bash
command -v chatgpt
chatgpt
```

Или пункт **ChatGPT** в rofi (`SUPER W`). `chatgpt` и `chatgpt-x11` — одно: XWayland.

Первый запуск: **Continue to sign in** → браузер → Pro.

## Wayland

Native Wayland на Hyprland роняет процесс (`Connection reset by peer`). Дефолт — X11, как у официального Linux preview.

```bash
chatgpt          # XWayland
chatgpt-x11      # то же, бинарь в PATH
chatgpt-wayland  # native Wayland, если хочешь рискнуть
```

Computer Use на Linux preview нет.

Диалог папки (Open project) нужен GTK3 schema `org.gtk.Settings.FileChooser`.
Обёртка тянет её через `wrapGAppsHook3`. Без rebuild: `GLib-GIO-ERROR` и core dump.

Плагины: Electron копирует `resources/plugins/openai-bundled` из nix store
с mode `0444`. Потом `writeFile`/`rmdir` → `EACCES`, marketplace пустой.
Лаунчер кладёт writable-копию в `~/.cache/chatgpt/openai-bundled` и
bind-mount через `bwrap`. Старые `~/.codex/.tmp/bundled-marketplaces/openai-bundled.staging-*`
можно стереть.

`ps -ax` в логах: в `~/.nix-profile` BusyBox перекрывает GNU `ps`.
Обёртка ставит `procps` первым в PATH только для ChatGPT.

Git-проект: `autoPatchelf` ломает `detect-libc`, Electron CFI → SIGILL
после `Starting git repo watcher`. В `app.asar` family принудительно `glibc`
(nixpkgs#551713). Crashpad `tag not found` — шум дампера, не причина.

## Обновление пакета

`latest` URL плавает. После смены upstream:

```bash
nix hash file chatgpt_amd64.deb
dpkg-deb -f chatgpt_amd64.deb Version
```

Правка: `home/programs/chatgpt/default.nix` (`version` + `hash`).

## Откат

`programs.chatgpt = false`, rebuild. Профиль `~/.config/chatgpt` Nix не трогает.
