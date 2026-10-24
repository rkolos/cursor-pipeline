# План: 09-install-lang-and-docs

## Цель

`install.sh --lang en|uk|ru` (default `en`, `TP_LANG`, persist `install.json`), документация Language, notify в `run-loop` из locale.

## Out of scope

- doctor (10), acceptance smoke IDE (11).

## Шаги

1. `install.sh`: парсинг `--lang` / `--uninstall`; resolve lang: flag → TP_LANG → install.json → `en`; symlink packs; write install.json.
2. README Language + troubleshooting; how-it-works markers table; CONTRIBUTING sync-all-langs.
3. `run-loop.sh`: notify через `i18n.mjs` + lang из state; PROMPT ссылается на `~/.cursor/commands/task-pipeline.md`.
4. Тест: `CURSOR_DIR=$TMP ./install.sh --lang uk` → symlinks на uk; повтор без флага читает install.json.

## DoD

- [x] --lang uk + persist
- [x] docs
- [x] tests green
