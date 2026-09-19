# Weylus: Android-планшет как графический планшет

Флаг: `features.weylus`. Пакет, группа `uinput`, TCP `1701` (HTTP) и `9001` (WebSocket).

Только в сети, которой доверяешь: шифрования нет.

## Включение

В `vars.nix`:

```nix
features.weylus = true;
```

Rebuild, затем **новый логин** (группа `uinput` иначе не действует).

```bash
groups | grep uinput
```

## Планшет по Wi-Fi

1. ПК и планшет в одной сети.
2. Запусти `weylus` (меню / `SUPER W`).
3. Задай access code, нажми Start.
4. На планшете открой URL с QR / строки Weylus, Firefox 80+ или Chrome.

Без общего Wi-Fi: hotspot на планшете или USB ниже.

## Планшет по USB (adb)

На планшете: USB debugging. Кабель в ПК:

```bash
adb reverse tcp:1701 tcp:1701
adb reverse tcp:9001 tcp:9001
```

На планшете: `http://127.0.0.1:1701`.

## Hyprland / Wayland

Захват экрана: PipeWire + `xdg-desktop-portal-hyprland` (уже в desktop-модуле). Первый захват спросит разрешение портала.

Не работает на Wayland: маппинг ввода на одно окно, нормальные имена окон, курсор в стриме.

Стилус (давление, наклон) и multi-touch идут через `uinput`, не через захват.

## Второй монитор

Не входит в этот модуль. Виртуальный выход Hyprland / dummy HDMI — отдельно.

## Откат

`features.weylus = false`, rebuild. После отключения группы нужен новый логин.
