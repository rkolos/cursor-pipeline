# Fact-report: 05-hook-followup-tests-ci

## Вердикт

Ветки `cmdHookFollowup` совпадают со спекой; сейчас частично покрыты только next-task/unblock через `tp-state.test.sh`. Изоляция через `HOME` в `run.sh` закрывает риск записи в реальный `active.json`. `hook.mjs stop` оставлен out of scope. Вопросов нет.

## Что исправлено

- **факт:** optional stop-тест явно out of scope.
- **edge:** `continueNextTask: false` правится в `state.json` config после init.

## Вопросы

нет
