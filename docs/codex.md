# ChatGPT Codex CLI

Флаг: `programs.codex`. Пакет `codex` из `nixpkgs-unstable` (сейчас `0.92.0`). Бинарь: `codex`.

Это терминальный агент OpenAI. GUI: [`docs/chatgpt.md`](chatgpt.md), флаг `programs.chatgpt`.

Nix не пишет ключи и не логинит аккаунт.

## Включение

В `vars.nix`:

```nix
programs.codex = true;
```

Если ключа нет, `vars.nix.example` даёт `true` через merge. Затем `./bin/update`.

```bash
command -v codex
codex --version
```

## Вход

В каталоге проекта:

```bash
codex
```

Первый запуск: **Sign in with ChatGPT** (Plus / Pro / Business / Edu / Enterprise). API key — отдельный путь, в Nix его не клади.

Токены живут в `~/.codex/auth.json`. Это секрет: не коммить, не класть в `vars.nix`.

## Личный стек

Хуки, skills и `agent-check` / `paper-check` живут в `~/multiagent-dev-stack`.
Nix их не ставит. Не копируй `AGENTS.md` в git продукта.

```bash
~/multiagent-dev-stack/install.sh
```

## Откат

`programs.codex = false`, rebuild. Каталог `~/.codex` Nix не трогает.
