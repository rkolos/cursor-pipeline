# Fact-report: 06-i18n-foundation

## Вердикт

План совпадает со спекой и эпиком: layout `ru/` + loader в 06, install default `ru`, new init `lang=en`. Soft set-config out of scope. Вопросов нет.

## Что исправлено

- **факт:** `DEFAULT_CONFIG` без `lang`, чтобы merge не навязывал en.
- **факт:** hook notice локализуется; followup строки — из locale по `state.config.lang`.

## Вопросы

нет
