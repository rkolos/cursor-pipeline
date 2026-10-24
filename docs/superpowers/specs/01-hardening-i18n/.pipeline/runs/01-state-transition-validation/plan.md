# План: 01-state-transition-validation

## Цель

В `scripts/tp-state.mjs` (`cmdSet`) добавить проверку допустимых комбинаций `status`/`phase` и соседних переходов `phase` при неизменном `in-progress`, плюс `--force` для аварийного обхода; расширить `tests/tp-state.test.sh` и коротко описать поведение в `docs/how-it-works.md`. Сообщения `fail` / warning — на русском (i18n — задача 06).

## Out of scope

- Infer статуса из имени файла (задача 02).
- Контракт commit-before-done и откат `done→in-progress` в commands/rules (задача 03); опциональная проверка «done только с предыдущей phase=commit» — тоже 03, не здесь.
- Изменение `cmdNext` / `cmdHookFollowup` / текстов followup (легальные `set` уже в промптах).
- i18n строк CLI (задача 06).
- Валидация переходов `status` как отдельный граф (кроме инвариантов итогового `status`+`phase` ниже).

## Шаги

1. **`scripts/tp-state.mjs` — `parseArgs`**
   - Сейчас любой `--flag` всегда съедает следующий argv (`flags[key] = argv[i+1]`), поэтому голый `--force` перед `--dir` сломает разбор.
   - По аналогии с `scripts/merge-hooks.mjs` (`--uninstall`): для ключа `force` ставить `flags.force = true` и **не** инкрементировать `i` на значение.
   - Остальные флаги (`status`, `phase`, `dir`) без изменений.

2. **`scripts/tp-state.mjs` — константы и `assertTransition`**
   - `WORK_PHASES` = `PHASES` без `'done'` → `plan|fact|awaiting-approval|implement|check|fix|commit`.
   - Граф соседства (только смена `phase` при **неизменном** `status === 'in-progress'`):

     | from | to |
     |---|---|
     | `null` | `plan`, `fact` |
     | `plan` | `fact` |
     | `fact` | `awaiting-approval`, `implement` |
     | `awaiting-approval` | `implement` |
     | `implement` | `check` |
     | `check` | `fix`, `commit` |
     | `fix` | `check`, `commit` |
     | `commit` | `fix` |

     Переход в `phase=done` только вместе со `status=done` (инвариант ниже), не через этот граф.

   - Сигнатура: `assertTransition({ prevStatus, prevPhase, nextStatus, nextPhase, phaseFlagPassed, force })` → возвращает итоговый `phase` (с учётом auto) или `fail(...)`.
   - Порядок в `cmdSet` (важно — сейчас мутация идёт сразу в `task`):
     1. Сохранить `prevStatus` / `prevPhase`.
     2. Посчитать `nextStatus` = `flags.status ?? prevStatus`.
     3. `phaseFlagPassed = flags.phase !== undefined`; сырой `nextPhase` = из флага (`null` если `--phase null`) или `prevPhase`.
     4. Вызвать `assertTransition` **до** записи в `task` и до `syncFileName`.
     5. Записать `task.status` / `task.phase`, затем существующая проверка «один in-progress», `syncFileName`, `writeJson`, `print`.
   - Правила `assertTransition`:
     - Whitelist `STATUSES` / `PHASES|null` — как сейчас (до или внутри assert; при невалидном значении — тот же `fail`).
     - `force` (truthy): однострочное предупреждение в **stderr** (`tp-state: …`), **не** проверять adjacency и инварианты 1–5 ниже; whitelist и «один in-progress» остаются. Auto-phase для `done`/`todo` (см. ниже) **всё равно** применять — это нормализация итога, не обход графа.
     - Без `force` — инварианты итога:
       1. `nextStatus === 'done'` → итоговый phase должен быть `done`. Если `phase` не передавали — подставить `done`. Если передали не `done` — fail.
       2. `nextStatus === 'todo'` → итоговый phase только `null`. Если `phase` не передавали — подставить `null`. Если передали не `null` — fail.
       3. `nextStatus === 'blocked'` → phase ∈ `WORK_PHASES`. Без `--phase`: оставить `prevPhase`; если `prevPhase` это `null` или `done` — fail. С `--phase`: только `WORK_PHASES` (не `null`, не `done`).
       4. `nextStatus === 'in-progress'` → phase ∈ `WORK_PHASES ∪ {null}`; `phase === 'done'` — fail.
       5. Если `prevStatus === 'in-progress'` и `nextStatus === 'in-progress'` и итоговый phase ≠ `prevPhase`: `from === to` уже отсеян; иначе `to` должен быть ∈ соседей `from` (ключ графа для `null`); иначе fail с текстом вида «запрещён переход phase X → Y; ожидалось: …».
     - Смена `status` (например `todo→in-progress --phase plan`, `plan→done --phase done`, `blocked→in-progress` без phase) **не** гоняется через граф соседей — только инварианты итога. Это сохраняет текущий тест `in-progress/plan` → `done/done` и старт/разблок из followup-промптов.
   - Обновить usage в `default` и комментарий в шапке файла: `set … [--status S] [--phase P] [--force]`.

3. **`tests/tp-state.test.sh`**
   - Сохранить существующие кейсы: init → start → rename in-work → `done`/`done` → hook `next-task`; blocked + `Рекомендация` → resume.
   - Добавить happy path полного цикла phase при `in-progress` (отдельная задача или продолжение после unblock — на усмотрение, главное не ломать unblock):  
     `plan → fact → implement → check → commit`, затем `--status done --phase done`.
   - Fail при `set -euo pipefail`: вызывать так, чтобы ненулевой exit не ронял скрипт раньше assert, например  
     `if $TP set … --dir "$TMP"; then echo FAIL: expected non-zero; exit 1; fi`  
     или `ec=0; $TP set … || ec=$?; [[ "$ec" -ne 0 ]]`.
   - Fail-кейсы (exit ≠ 0, stderr непустой / содержит суть):
     - уже `in-progress`/`plan`, только `--phase commit`;
     - `in-progress` + `--phase done`;
     - `todo` + `--phase plan` (или `--status todo --phase plan`);
     - `done` + `--phase commit` (или `--status done --phase commit`);
     - `--status blocked` при текущей `phase=null` без `--phase`.
   - `--force`: тот же `plan → --phase commit --force` → exit 0; JSON в stdout; stderr содержит предупреждение (проверять через `2>` отдельно от stdout).

4. **`docs/how-it-works.md`**
   - После блока Phases / строки Statuses — короткий абзац: `tp-state set` проверяет инварианты status/phase и соседние phase при `in-progress`; `--force` обходит эти проверки для ремонта (whitelist и «один in-progress» остаются). Без истории правок.

## DoD / приёмка

- [ ] Нелегальный `set` → exit 1 и stderr с запрещённой парой / ожиданием.
- [ ] Легальный полный цикл `plan→fact→implement→check→commit→done` в тесте проходит.
- [ ] Существующие кейсы rename / next-task / auto-unblock по-прежнему зелёные.
- [ ] `--force` обходит adjacency; stderr — предупреждение; stdout — JSON как раньше.
- [ ] `set --status done` без `--phase` нормализует `phase=done`; `set --status todo` без `--phase` — `phase=null`.
- [ ] Абзац про валидацию в `docs/how-it-works.md`.
- [ ] `./tests/run.sh` зелёный; `node --check scripts/tp-state.mjs` ок.

## Как проверить

```bash
./tests/run.sh
node --check scripts/tp-state.mjs
```

Узко (после правок теста): `bash tests/tp-state.test.sh`.

## Edge cases

| Кейс | Поведение / критерий |
|---|---|
| `set --status done` без `--phase` (был `commit`) | auto `phase=done` |
| `set --status todo` без `--phase` | auto `phase=null` |
| `set --status done --phase null` / `--phase commit` | fail |
| `set --status blocked --phase done` или blocked при `phase=null` без флага | fail |
| `set --phase plan` когда уже `plan` | no-op, OK |
| `set --status blocked` при `phase=implement` без `--phase` | keep implement, OK |
| `set --status in-progress` без `--phase` с `todo`/`null` | `in-progress` + `null`, OK (граф не применяется) |
| `set --status in-progress --phase plan` с `todo` | OK (смена status, не adjacency) |
| Уже `in-progress`/`plan` + `--status in-progress --phase commit` | fail (status неизменен → граф) |
| `commit → --phase done` при `in-progress` | fail (нужен `status=done`) |
| Два `in-progress` | существующий fail, логику не дублировать в assert |
| `--force` + невалидный `--status foo` | по-прежнему fail по whitelist |
