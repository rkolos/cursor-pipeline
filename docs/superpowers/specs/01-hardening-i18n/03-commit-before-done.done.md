# Spec 01 — Task 03 — Mark `done` only after successful commit

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **03** · priority **P0**  
**Depends on:** [01](01-state-transition-validation.done.md)

## Description

В `commands/task-pipeline.md` § commit сейчас: сначала `TP set … --status done --phase done`, потом stage/commit/push. Если commit падает, задача уже `done` в state и файле `.done.md`.

Изменить контракт агента (все локали появятся в 07–08; **сейчас править существующий RU** `commands/task-pipeline.md` + rule):

1. Во время commit phase статус остаётся `in-progress`, phase=`commit`.
2. Канонический порядок одного commit (без второго amend под rename):
   - подготовить все file changes → `TP set --status done --phase done` (rename `.in-work`→`.done`) → `git add` включая rename → один `git commit`;
   - если commit **упал** после `set done`: `TP set --status in-progress --phase commit --force` (файл снова `.in-work` через set), описать в `fix-plan.md`, остаться в commit phase.
3. Зафиксировать этот порядок и rollback в команде явно (нумерованные шаги).
4. Добавить/обновить always-on rule `rules/task-pipeline-commit-before-done.mdc` (или секция в `task-pipeline-no-stop.mdc` — предпочтительно **отдельный** короткий mdc, чтобы 07–08 копировали три файла одинаково).

Опционально (если дёшево): `tp-state set` при `status=done` проверяет, что phase была `commit` или уже `done` (с `--force` иначе). Не требовать git-clean в скрипте (агент вне process).

## Files

- Modify: `commands/task-pipeline.md` (§ 8 commit, § 9 итог)
- Create: `rules/task-pipeline-commit-before-done.mdc` (`alwaysApply: true`)
- Modify: `install.sh` — линковать новый rule
- Modify: `docs/how-it-works.md` — Phases / commit note
- Modify: `scripts/tp-state.mjs` — опциональный soft-check done←commit

## Pay attention

- `run-loop.sh` / `TP_AUTONOMOUS=1` не меняют порядок — только checks.
- Не требовать push success для `done` (push failure → запись в deferred todo, задача done) — как сейчас в команде.
- Rollback path должен работать с transition validation из 01 (`--force` если нужно).

## Definition of done

- [ ] Текст команды и rule однозначно: нет «done до успешного commit» без описанного rollback.
- [ ] `install.sh` ставит новый rule.
- [ ] Нет противоречий с `task-pipeline-no-stop.mdc` / autonomous-checks.
- [ ] `./tests/run.sh` зелёный (скрипты не обязаны e2e git).
