# Установка с NixOS ISO (live)

## Что происходит при загрузке с флешки

ISO грузит **live-систему в RAM**, не установку на диск. `nixos-rebuild switch` меняет только live-сессию.

Для записи на диск нужен **`nixos-install`**. Wizard `bin/setup` → режим **1) Установка с ISO**.

## Порядок

1. Загрузиться с USB (NixOS minimal/TUI)
2. Логин `root`, настроить сеть (`ping nixos.org`)
3. Разметить диск: `cfdisk /dev/sdX`
4. Смонтировать:
   ```bash
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-label-boot /mnt/boot   # EFI
   ```
5. (Рекомендуется) Swap при мало RAM:
   ```bash
   fallocate -l 8G /swapfile
   chmod 600 /swapfile
   mkswap /swapfile
   swapon /swapfile
   ```
6. Клонировать и setup:
   ```bash
   git clone https://github.com/mhalynchik/nix-config.git ~/nixos-config
   cd ~/nixos-config
   ./bin/setup
   ```
7. Выбрать **1) Установка с ISO**
8. В wizard — **минимальные флаги** (gaming, docker, nvidia, cursor = false)
9. Подтвердить `nixos-install`
10. `reboot`, снять флешку

После первого входа: включить модули через `~/nixos-config/bin/update`.

## Память

Сборка на live ISO жрёт RAM. При OOM — swap + меньше флагов в `vars.nix`.
