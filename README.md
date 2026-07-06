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

**Flake и vars.nix:** если `/etc/nixos` — git repo, flake видит только **закоммиченные** файлы. Wizard после setup/update делает `git add` + `git commit` (включая `vars.nix`, `hardware-configuration.nix` и файлы после deploy). В GitHub они не попадают — remote только у `~/nixos-config`.

## Первый запуск

```bash
git clone https://github.com/mhalynchik/nixos.git ~/nixos-config
cd ~/nixos-config
./bin/setup
```

Wizard:
1. Синхронизирует конфиг в `/etc/nixos`
2. Создаёт `vars.nix` (интерактивно)
3. Генерирует `hardware-configuration.nix` (если нет)
4. Коммитит изменения в `/etc/nixos`
5. Собирает и предлагает `switch`

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
| `ags`, `spotify`, `telegram`, `planify` | Приложения |
| `cursor`, `vscode`, `zed`, `lunarvim` | Редакторы |
| `steam` | Steam theme module |

Также: `browser` (`floorp`), `terminal` (`kitty`), `theme` (`catppuccin` / `crimson`).

Шаблон: [`vars.nix.example`](vars.nix.example)

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
sudo nixos-rebuild switch --flake /etc/nixos# --impure
```

`--impure` нужен для модуля Cursor (AppImage из `~/.local/opt/cursor/`).

## Документация

- [Мультимонитор](docs/multi-monitor.md)
- [Playwright на NixOS](docs/playwright.md)
- [MAX sandbox VM](docs/max-sandbox-vm.md)
- [Windows bootable USB](docs/windows-bootable-usb.md)

## Миграция

1. Скопировать repo: `cp -a /etc/nixos ~/nixos-config`
2. В `~/nixos-config`: настроить remote на GitHub, убедиться что `vars.nix` в `.gitignore`
3. `./bin/deploy.sh` — синхронизирует в `/etc/nixos`, **не трогает** `.git` в `/etc/nixos`
4. Локально в `/etc/nixos`: wizard коммитит `vars.nix`, `hardware-configuration.nix` и deploy-изменения

Локальный git в `/etc/nixos` остаётся для своих коммитов. Remote — только у `~/nixos-config`.
