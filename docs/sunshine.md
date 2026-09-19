# Sunshine + Moonlight

Флаг: `features.sunshine`. Одно приложение: **Desktop** (зеркало текущего монитора).

Capture: `kms`. Encoder: `software`. Звук выкл. PIN: [https://localhost:47990](https://localhost:47990).

Второй экран убран: Hyprland headless `TABLET` забирал workspace 2 и 10 на невидимый выход. KMS этот выход не снимает — extend на NVIDIA+Hyprland здесь не работает.

## Качество

Картинку режет bitrate Moonlight. В логе было `7308000` (7 Мбит/с) на 2560×1440.

У хоста в Moonlight (шестерёнка этого ПК):

1. Выключи автобитрейт
2. Video bitrate → **40000**
3. Codec **H.264**

```bash
journalctl --user -u sunshine -n 40 --no-pager | rg "Streaming bitrate"
```

Нужно `40000000`.

## Откат

`features.sunshine = false`, rebuild.
