# План: 03-commit-before-done

## Цель

Зафиксировать контракт агента: на фазе `commit` статус остаётся `in-progress` до успешного `git commit`; `TP set done` делается сразу перед stage одного commit (чтобы rename попал в него); при падении commit — rollback `--force` в `in-progress`/`commit`. Отдельное always-on rule + правка RU-команды и how-it-works.

## Out of scope

- Локали EN/UK commands/rules (07–08).
- Soft-check в `tp-state` «done только из phase=commit» — опционально; **пропуск** (см. `questions.md` Q1): не в DoD, ломает короткие тестовые `plan→done` без пользы для агентского контракта.
- Изменение порядка checks / Docker / push-failure→deferred.

## Шаги

1. **`commands/task-pipeline.md` §8** — переписать нумерованные шаги:
   - 1–3: Remote, проверки, Docker cleanup (как сейчас; статус всё ещё `in-progress`/`commit`).
   - 4: резюме в чат.
   - 5: подготовить изменения → `TP set --status done --phase done` (rename) → `git add` (включая rename и `.pipeline/`) → один `git commit`.
   - 6: если `git commit` упал → `TP set --status in-progress --phase commit --force`, описать в `fix-plan.md`, остаться в commit; не считать задачу закрытой.
   - 7: сообщение коммита; 8: push (`push: true`); push failure не откатывает done.
   - Убрать формулировку «Отметка до коммита» как единственный акцент без rollback.
2. **`rules/task-pipeline-commit-before-done.mdc`** — `alwaysApply: true`, кратко: не оставлять `done` без успешного commit; порядок set done → add → commit; rollback через `--force`.
3. **`install.sh`** — уже линкует `rules/task-pipeline-*.mdc`; новый файл подхватится без правки. Проверка: убедиться, что цикл на месте (при необходимости одна строка-комментарий).
4. **`docs/how-it-works.md`** — в строке phase `commit` / абзац: mark `done` только вместе с успешным git commit; rollback при failure.
5. Не менять `tp-state.mjs` (soft-check пропущен).
6. `./tests/run.sh` — регрессия без новых e2e git.

## DoD / приёмка

- [ ] §8 + rule однозначно описывают порядок и rollback.
- [ ] Новый `.mdc` в `rules/`; `install.sh` ставит его через существующий glob.
- [ ] Нет противоречий с `task-pipeline-no-stop` / autonomous-checks.
- [ ] how-it-works обновлён.
- [ ] `./tests/run.sh` зелёный.

## Как проверить

```bash
./tests/run.sh
# глазами: commands/task-pipeline.md §8, rules/task-pipeline-commit-before-done.mdc
ls rules/task-pipeline-commit-before-done.mdc
```

## Edge cases

| Кейс | Поведение |
|---|---|
| Commit fail после set done | rollback `--force` → in-progress/commit |
| Push fail | задача остаётся done; deferred todo |
| Проверки fail до set done | `phase fix`, status ещё in-progress |
