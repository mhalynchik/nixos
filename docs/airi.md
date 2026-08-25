# AIRI, Ollama, Whisper и Piper

Флаги независимы: окно AIRI, Ollama, Whisper, Piper, или любая смесь.

## Флаги

| Ключ | Назначение |
|------|------------|
| `programs.airi` | пакет Tamagotchi в home-профиле |
| `features.ollama` | `ollama.service` на localhost |
| `ollama.host` / `ollama.port` | адрес сервиса (по умолчанию `127.0.0.1:11434`) |
| `ollama.loadModels` | фоновый `ollama pull` после старта; `[]` = тянуть вручную |
| `features.whisper` | `whisper.service` (OpenAI-compatible STT) |
| `whisper.host` / `whisper.port` | адрес (по умолчанию `127.0.0.1:8178`) |
| `whisper.model` | faster-whisper: `tiny` / `base` / `small` / `medium` / `large-v3` / `turbo` |
| `whisper.language` | язык транскрипта (`ru`) |
| `whisper.device` | `cpu` (25.05 `ctranslate2` без CUDA). `cuda` пробует GPU и падает на CPU |
| `features.piper` | `piper.service` (OpenAI-compatible TTS, Irina) |
| `piper.host` / `piper.port` | OpenAI-compatible порт (по умолчанию `127.0.0.1:8179`). Player2 ещё слушает `:4315` |

Pin AIRI: `v0.12.0-beta.1` (`f14a7ac9a169290d2469a519c4387e3fe3ba2186`). Vanilla-тег не собирается; overlay в `home/programs/airi`.

Nix не пишет провайдер и не кладёт ключи в JSON AIRI. Выбор роли только в UI.

## Onboarding: локальный чат

В AIRI: Sign in пропустить / свой провайдер → **Ollama**. URL по умолчанию `http://localhost:11434/v1/`. Модель выбрать из `ollama list`.

## Модели Ollama

Сервис не видит `~/.ollama` (`ProtectHome`). Каталог: `/var/lib/ollama/models`.

```bash
OLLAMA_HOST=http://127.0.0.1:11434 ollama pull gemma3
OLLAMA_HOST=http://127.0.0.1:11434 ollama list
```

`systemctl is-active ollama` не значит, что модель уже на диске. `loadModels` качает в фоне.

## GPU (чат)

При `features.nvidia` Ollama идёт с `acceleration = "cuda"`. Проверка: во время ответа `ollama ps` показывает GPU.

## Голос: STT (фаза 3b)

Клиентский STT AIRI на русском слаб: Web Speech API на Tamagotchi выключен, встроенный транскрипт часто врёт. Локальный путь: `whisper.service`.

Первый старт качает модель в `/var/lib/whisper/models` (минуты, нужен интернет). Юнит `active` ≠ порт уже слушает: старый бинарь биндит 8178 только после загрузки. После правки `/health` сразу отвечает `loading` (HTTP 503) или `ok`.

```bash
systemctl is-active whisper
curl -sS http://127.0.0.1:8178/health
journalctl -u whisper -f
```

В AIRI два места.

1. Settings → Providers → Transcription → **OpenAI Compatible**
   - Base URL: `http://127.0.0.1:8178/v1/` (обязательный `/` в конце)
   - API Key: любой непустой, например `local` (сервис ключ не проверяет, слушает только localhost)
2. Settings → Modules → Hearing → этот провайдер. Поле модели: вручную **`whisper-1`**. Список не кликабелен: AIRI у compatible STT `/v1/models` не рисует.

Сервер имя игнорирует и всегда крутит `whisper.model` из Nix (сейчас `medium`). Подойдёт и `medium`. Пустое поле = AIRI ругается.

Hearing должен указывать на этот Transcription-провайдер. Rebuild после смены URL в UI не нужен.

Качество на CPU: `medium` (дефолт) для живого диалога. Лучше и медленнее: `large-v3`. Быстрее и хуже: `small`.

## Голос: TTS

Kokoro обучен в основном на английском: русский хрипит и срывается в EN/ZH. Локальный путь: Piper, голос `ru_RU-irina-medium`.

Два юнита при `features.piper`:

- `piper.service` на `:8179` (OpenAI `/v1/audio/speech`). Карточка OpenAI Compatible Speech на AIRI `v0.12.0-beta.1` ключ в стор не пишет. Не используй её для Piper.
- `piper-player2.service` на `:4315` (протокол Player2). Это рабочий путь.

```bash
systemctl is-active piper piper-player2
curl -sS http://127.0.0.1:4315/v1/health
curl -sS http://127.0.0.1:4315/v1/tts/voices
```

Настоящий Player2 (`player2.game`) не ставь: русского нет.

На этой сборке Settings → Speech → Player2 карточка Validate не сохраняет (Pinia `configs` computed). Голос держится в localStorage origin `file://`:

- `settings/providers/configured` → `player2-speech`: `status=configured`, `baseUrl=http://127.0.0.1:4315/v1/`, `model=player2-tts`, `voice=irina`
- `settings/providers/added` → `player2-speech=true`
- `settings/speech/active-provider=player2-speech`
- `settings/speech/active-model=player2-tts`
- `settings/speech/voice=irina`

AIRI перед правкой LevelDB закрыть целиком: у главного `electron` нет `user-data-dir` в argv, `pkill` по этому флагу убивает только хелперы. Nix/HM этот JSON не пишет.

Если голос пропал после кликов в UI: те же ключи, rebuild не нужен.

Облако: ElevenLabs / Azure / другой Speech. Ключ только в UI.

Чат-модель тоже может отвечать не по-русски. Тогда Piper прочитает английский русскими фонемами. В карточке персонажа: всегда отвечай по-русски. Язык UI: `ru`.

## Окно на Hyprland

Сцена (`title` = `AIRI`, class `ai-moeru-airi`): fullscreen, без тайла, без блюра композитора. Окно Chat обычное. Снять fullscreen: `SUPER+F`.

Внутренний CSS-блюр самой AIRI Hyprland не снимает.

## История (фаза 4)

userData Tamagotchi: `~/.config/ai.moeru.airi`.

Там окно, язык, IndexedDB и File System (чат / встроенная база). Критерий плана: история на месте после закрытия окна, не Memory Alaya.

Бэкап:

```bash
tar -C "$HOME/.config" -czf airi-userdata.tgz ai.moeru.airi
```

Не копировать этот каталог через Home Manager: внутри могут быть ключи провайдеров.

Если история пропала: не поднимать PostgreSQL первым шагом. Проверить, что AIRI пишет в этот путь, и что профиль не чистится.

## Смена ролей на облако (фаза 5)

Одна роль в UI, остальные не трогаем. Flake и rebuild не нужны.

| Роль | Локально | Облако в UI |
|------|----------|-------------|
| Чат | Ollama `http://localhost:11434/v1/` | OpenAI / Anthropic / OpenRouter / OpenAI-compatible |
| STT | Whisper `http://127.0.0.1:8178/v1/` | OpenAI Whisper / другой Transcription |
| TTS | Player2 / Piper `http://127.0.0.1:4315/v1/` (`:8179` запасной OpenAI, AIRI его не берёт) | ElevenLabs / Azure / другой Speech |
| VAD | клиент AIRI | не меняем |

Ключи облака только в Settings AIRI. Не в `vars.nix`, wizard, Home Manager, store.

## Запрет ключей

Nix пишет только флаги, URL localhost и имена локальных моделей. Home Manager каталог `~/.config/ai.moeru.airi` не копирует. Разовая правка localStorage вручную допустима (см. TTS); ключи облака туда не класть.

## Откат

`programs.airi = false` и/или `features.ollama = false` и/или `features.whisper = false` и/или `features.piper = false`, затем rebuild или `--rollback`.
