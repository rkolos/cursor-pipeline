# План: 08-locale-ukrainian

## Цель

Повний UK-пакет: `commands/uk/*`, `rules/uk/*` (семантика 1:1 з EN/RU), `uk.json` (вже з 06), тест followup при `lang=uk`.

## Out of scope

- install `--lang` (09), зміна default install з ru.

## Шаги

1. `commands/uk/{task-pipeline,tp-fact,tp-check}.md` — переклад з EN, мітки `Рекомендація:` / `Відповідь:`.
2. `rules/uk/task-pipeline-*.mdc` — усі 4.
3. Підтвердити `uk.json`.
4. Тест: state.lang=uk → followup містить `Продовжуй конвеєр`.

## DoD

- [ ] UK commands + rules
- [ ] uk.json повний
- [ ] тест followup uk
- [ ] `./tests/run.sh` зелений
