# Spec 01 — Task 10 — `tp-state doctor`

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **10** · priority **P1**  
**Depends on:** [01](01-state-transition-validation.md), [02](02-init-infer-status-from-filename.md), [06](06-i18n-foundation.md)

## Description

Новая команда:

```bash
node ~/.cursor/task-pipeline/tp-state.mjs doctor [--dir D] [--fix]
```

Без `--fix` — только отчёт JSON:

- `fileStatusMismatch`: status в state не соответствует суффиксу файла (todo↔plain, in-progress|blocked↔`.in-work`, done↔`.done`)
- `multipleInProgress`
- `phaseStatusIllegal` (те же правила, что validation)
- `missingTaskFile`
- `orphanRunDirs`: `runs/<id>` без задачи в state (info)
- `questionsBlockedUnanswered`: blocked + пустые Answer
- `lang`: текущий resolved lang

С `--fix` (осторожный авторемонт):

- mismatch имени → `syncFileName` под status (не наоборот), кроме случая «файл `.done` а status todo» — тогда status→done (безопаснее для recovery)
- multiple in-progress → как в init (первая остаётся, остальные blocked)
- Не удалять orphan runs автоматически
- Не заполнять Answer за пользователя

Сообщения doctor — через locale JSON.

## Files

- Modify: `scripts/tp-state.mjs` (`cmdDoctor`)
- Modify: `tests/tp-state.test.sh` — mismatch detection + optional fix
- Modify: `README.md` State CLI table
- Modify: `docs/how-it-works.md`

## Pay attention

- `--fix` не делает git commit.
- Exit code: `0` если ошибок нет; `1` если есть problems (даже если --fix всё починил — или `0` after successful fix: выбрать **0 если после fix problems пуст, иначе 1**).

## Definition of done

- [ ] `doctor` без fix возвращает список проблем.
- [ ] `doctor --fix` чинит file↔status и multiple in-progress (тест).
- [ ] Документирован в README.
- [ ] `./tests/run.sh` зелёный.
