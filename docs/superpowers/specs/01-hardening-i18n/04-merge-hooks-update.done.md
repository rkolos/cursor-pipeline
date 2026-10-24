# Spec 01 — Task 04 — `merge-hooks`: update existing pipeline entries

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **04** · priority **P0**  
**Depends on:** —

## Description

`merge-hooks.mjs` при наличии hook с marker `task-pipeline/hook.sh` **не обновляет** entry (timeout, loop_limit, command path). Reinstall после изменения `hooks/hooks.json` не доставляет правки.

Поведение:

1. Для каждого event из fragment: взять pipeline-entries из fragment.
2. В target: удалить все entries с marker, затем append актуальные pipeline-entries (сохраняя **порядок и содержимое** non-pipeline hooks).
3. Uninstall — без изменений логики (filter out marker).
4. Идемпотентность: повторный merge даёт тот же JSON (стабильный pretty-print как сейчас).

Добавить unit/shell тест: временный hooks.json с чужим hook + старым pipeline (timeout 5) → merge fragment (timeout 15, loop_limit 100) → чужой на месте, pipeline обновлён.

## Files

- Modify: `scripts/merge-hooks.mjs`
- Create: `tests/merge-hooks.test.sh`
- Modify: `tests/run.sh` — вызвать новый тест
- Modify: `CONTRIBUTING.md` — одна строка про update hooks

## Pay attention

- Не трогать hooks без marker.
- Marker match: `String(command).includes('task-pipeline/hook.sh')` как сейчас.
- Не symlink `merge-hooks.mjs` в `~/.cursor/task-pipeline/` (install only).

## Definition of done

- [ ] Re-merge обновляет timeout/loop_limit pipeline-hook.
- [ ] Чужие hooks сохраняются.
- [ ] Uninstall по-прежнему чистит только pipeline.
- [ ] `./tests/run.sh` зелёный.
