# AIRI и Ollama

Флаги независимы: только окно AIRI, только сервис Ollama, или оба.

## Флаги

| Ключ | Назначение |
|------|------------|
| `programs.airi` | пакет Tamagotchi в home-профиле |
| `features.ollama` | `ollama.service` на localhost |
| `ollama.host` / `ollama.port` | адрес сервиса (по умолчанию `127.0.0.1:11434`) |
| `ollama.loadModels` | фоновый `ollama pull` после старта; `[]` = тянуть вручную |

Pin AIRI: `v0.12.0-beta.1` (`f14a7ac9a169290d2469a519c4387e3fe3ba2186`). Vanilla-тег не собирается; overlay в `home/programs/airi`.

## Onboarding: локальный чат

Nix не пишет провайдер и не кладёт ключи. В AIRI: Sign in пропустить / свой провайдер → **Ollama**. URL по умолчанию `http://localhost:11434/v1/`. Модель выбрать из `ollama list`.

## Модели

Сервис не видит `~/.ollama` (`ProtectHome`). Каталог: `/var/lib/ollama/models`.

```bash
OLLAMA_HOST=http://127.0.0.1:11434 ollama pull gemma3
OLLAMA_HOST=http://127.0.0.1:11434 ollama list
```

`systemctl is-active ollama` не значит, что модель уже на диске. `loadModels` качает в фоне.

## GPU

При `features.nvidia` сервис идёт с `acceleration = "cuda"`. Проверка: во время ответа `ollama ps` показывает GPU.

## Голос и история

Hearing / Speech (Kokoro) и персист чата настраиваются в UI AIRI. Ключи облака только там, не в `vars.nix`.

## Откат

`programs.airi = false` и/или `features.ollama = false`, затем rebuild или `--rollback`.
