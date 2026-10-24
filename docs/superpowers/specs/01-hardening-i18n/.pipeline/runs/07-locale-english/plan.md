# План: 07-locale-english

## Цель

Полный EN-пакет: `commands/en/*`, `rules/en/*` (семантика 1:1 с RU, включая commit-before-done), подтвердить `en.json`, пример questions с EN-метками, тест hook-followup при `lang=en`.

## Out of scope

- UK locale (08), install `--lang` (09), перевод README целиком.

## Шаги

1. Создать `commands/en/{task-pipeline,tp-fact,tp-check}.md` — перевод с ru, `Recommendation`/`Answer`.
2. Создать `rules/en/task-pipeline-*.mdc` (все 4).
3. `en.json` — уже полные строки; ревью без TODO.
4. `docs/examples/tasks/` — образец questions или note с EN-метками.
5. Тест: state.lang=en → next-task followup содержит `Continue the task pipeline`.

## DoD

- [ ] EN commands + rules
- [ ] en.json без stubs
- [ ] тест followup en
- [ ] `./tests/run.sh` зелёный
