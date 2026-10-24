# План: 04-merge-hooks-update

## Цель

Сделать `merge-hooks.mjs` идемпотентным **update**: при reinstall/merge заменять pipeline-entries (по marker) актуальными из fragment, не трогая чужие hooks.

## Out of scope

- Symlink merge-hooks в `~/.cursor/task-pipeline/`
- Изменение uninstall-логики
- Правки `hooks/hooks.json` содержимого (только доставка через merge)

## Шаги

1. **`scripts/merge-hooks.mjs`**: для каждого event из fragment с pipeline-entries — `others = current.filter(!pipeline)`, затем `base.hooks[event] = [...others, ...pipelineEntries]` (убрать early-return `if (hasPipeline)`).
2. **`tests/merge-hooks.test.sh`**: target с чужим hook + старый pipeline (timeout 5); fragment timeout 15 / loop_limit 100 → чужой сохранён, pipeline обновлён; повторный merge → тот же JSON; uninstall → только pipeline убран.
3. **`tests/run.sh`**: вызвать новый тест.
4. **`CONTRIBUTING.md`**: строка — re-merge обновляет pipeline entries по marker.

## DoD

- [ ] Re-merge обновляет timeout/loop_limit.
- [ ] Чужие hooks на месте.
- [ ] Uninstall чистит только pipeline.
- [ ] `./tests/run.sh` зелёный.

## Как проверить

```bash
./tests/run.sh
bash tests/merge-hooks.test.sh
```

## Edge cases

| Кейс | Поведение |
|---|---|
| Нет pipeline в target | append как раньше |
| Два pipeline в target | оба удаляются, ставятся из fragment |
| Event только в target | не трогаем (цикл по fragment) |
