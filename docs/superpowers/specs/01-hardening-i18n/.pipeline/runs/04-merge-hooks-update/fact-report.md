# Fact-report: 04-merge-hooks-update

## Вердикт

Текущий `merge-hooks.mjs` при `hasPipeline` пропускает event — баг спеки подтверждён. Marker и uninstall уже корректны. План минимален и совпадает с DoD. Вопросов нет.

## Что исправлено

- **факт:** замена = filter non-pipeline + append fragment pipeline (не in-place mutate полей).
- **edge:** несколько устаревших pipeline-entries на одном event снимаются одним проходом.

## Вопросы

нет
