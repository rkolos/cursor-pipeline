# План: 00-plan (kickoff эпика)

## Цель

Принять эпический roadmap Hardening + i18n (`00-plan.in-work.md` + задачи `01`–`11`) как стартовую точку конвейера: подтвердить полноту и согласованность содеревом репозитория `cursor-pipeline`, без правок продуктового кода. Реализация — только в задачах `01`–`11`.

## Out of scope

- Правки `scripts/`, `commands/`, `rules/`, `install.sh`, `tests/`, README/CONTRIBUTING (кроме косвенного включения в git только `docs/superpowers/`).
- Старт реализации `01`–`11` в этой задаче.
- Выбор symlink vs канон для `lang=ru` (задача `06`).
- CI (`.github/`), `doctor`, локали EN/UK, `install.sh --lang`.
- Переустановка `~/.cursor/task-pipeline` / смена target symlink на этот clone (среда агента; задачи `04`/`09`).

## Фактческая база (проверено на fact)

Точки касания эпика в корне репо существуют:

- `scripts/tp-state.mjs`, `scripts/hook.mjs`, `scripts/hook.sh`, `scripts/merge-hooks.mjs`, `scripts/run-loop.sh`
- `commands/{task-pipeline,tp-fact,tp-check}.md`
- `rules/task-pipeline-{autonomous-checks,no-stop,recommended-answers}.mdc`
- `tests/{run.sh,hook-question.test.sh,tp-state.test.sh}`
- `install.sh`, `docs/how-it-works.md`

Задачи `01`–`11`: у каждой есть `## Description`, `## Files`, `## Definition of done`. Зависимости из эпика соблюдены в тексте: `07`/`08` после `06`; `11` после `01`–`10`.

`./tests/run.sh` на момент fact — зелёный (sanity, не DoD кода этой задачи).

`tp-state` при rename задачи через `syncFileName` → `rewriteReferences` обновляет упоминания старого имени файла в соседних `.md`/`.json` папки задач (в т.ч. строки `Parent plan` в `01`–`11`).

В проекте нет `AGENTS.md` / `CLAUDE.md` / `.cursor/rules/` — критерии фактчека берутся из эпика и кода репо.

## Шаги

1. Сверить дерево касаний и файлы `01`–`11` (уже сделано на fact; при implement не повторять исследование — опираться на `fact-report.md`).
2. Зафиксировать kickoff-вердикт: эпик готов к `01+`; продуктового диффа нет.
3. На фазе commit: закоммитить только дерево `docs/superpowers/` (включая `.pipeline/` этой папки); `TP set 00-plan --status done` → файл `00-plan.done.md` и автообновление ссылок `Parent plan`; push при `config.push: true`.

## DoD / приёмка

Сделано, когда:

- [ ] `plan.md` + `fact-report.md` подтверждают готовность эпика к задачам `01+`.
- [ ] Нет staged/committed диффа вне `docs/superpowers/`.
- [ ] Задача `00-plan` в статусе `done`, файл `00-plan.done.md`; ссылки `Parent plan` в `01`–`11` указывают на `.done`.
- [ ] Коммит в истории со ссылкой на `00-plan`; remote обновлён, если push успешен.

## Как проверить

```bash
ls docs/superpowers/specs/01-hardening-i18n/0{1..9}-*.md docs/superpowers/specs/01-hardening-i18n/1{0,1}-*.md
test -f scripts/tp-state.mjs && test -f scripts/hook.mjs && test -f scripts/merge-hooks.mjs
test -f install.sh && test -f docs/how-it-works.md
./tests/run.sh
git status -sb
git log -1 --oneline
```

После commit: `node ~/.cursor/task-pipeline/tp-state.mjs next --dir docs/superpowers/specs/01-hardening-i18n` указывает на `01-state-transition-validation`.

## Edge cases

| Кейс | Решение |
|---|---|
| `00-plan` — метадокумент в очереди | Kickoff без кода; закрываем осознанно (цель выше) |
| Ссылки `Parent plan` на суффикс статуса | `TP set … --status done` переименует файл и вызовет `rewriteReferences` |
| Baseline `./tests/run.sh` красный | На fact был зелёный; если покраснеет до commit — записать в `.pipeline/todo.md` для `01`/`05`, kickoff не блочить |
| `~/.cursor/task-pipeline` symlink на другой clone | Out of scope этой задачи; не чинить install из kickoff |
