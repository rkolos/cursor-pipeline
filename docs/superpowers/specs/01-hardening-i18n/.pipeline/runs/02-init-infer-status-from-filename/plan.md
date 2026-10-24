# План: 02-init-infer-status-from-filename

## Цель

В `cmdInit` восстанавливать status/phase **новых** задач из суффикса имени файла (`.in-work` → `in-progress`/`plan`, `.done` → `done`/`done`, plain → `todo`/`null`); при нескольких `in-progress` оставлять первую по порядку файлов, остальные → `blocked` с warning; не трогать status уже известных id.

## Out of scope

- `tp-state doctor` (задача 10).
- Различение `blocked` vs `in-progress` только по имени (невозможно; recovery всегда `in-progress`).
- Переименование файлов в `init`.
- Изменения `cmdSet` / transition validation (01).

## Шаги

1. **`scripts/tp-state.mjs`**
   - Helper `statusFromFileName(file)` → `{ status, phase }` по таблице спеки.
   - В `cmdInit` для id **не** в `known`: брать результат helper вместо `done|todo`.
   - Для id в `known`: `{ ...existing, file }` без смены status/phase.
   - После сборки `tasks`: если `in-progress` > 1 — первую (порядок `listTaskFiles` / sort имени) оставить, остальные `status=blocked` (phase сохранить или `plan` если null); stderr: `tp-state: предупреждение: несколько in-progress при init, оставлен <id>, в blocked: …`.
   - Init не `fail` из‑за дублей in-progress.

2. **`tests/tp-state.test.sh`**
   - Отдельный TMP (или подкаталог): `001-a.in-work.md` + `002-b.md`, без state → init → JSON/state: 001 in-progress, 002 todo.
   - Два `.in-work` → init exit 0; ровно один in-progress, второй blocked; stderr с предупреждением.
   - Known: init → set in-progress → удалить только смысл «повторный init» с тем же state: status не сбрасывается в todo; отдельно: файл `.in-work` без state уже покрыт первым тестом. Для «не затирает»: init, set phase fact, повторный init → phase остаётся `fact`.

3. **`docs/how-it-works.md`** — в File naming: при `init` без/с потерей state суффиксы восстанавливают status; `blocked` из имени не восстанавливается (`.in-work` → `in-progress`).

## DoD / приёмка

- [ ] Тест: `.in-work` + plain без state → in-progress + todo.
- [ ] Тест: два `.in-work` → один in-progress, второй blocked, exit 0, warning.
- [ ] Повторный init с known id не затирает status/phase.
- [ ] `./tests/run.sh` зелёный; `node --check scripts/tp-state.mjs`.

## Как проверить

```bash
node --check scripts/tp-state.mjs
bash tests/tp-state.test.sh
./tests/run.sh
```

## Edge cases

| Кейс | Поведение |
|---|---|
| Только `.done.md` без state | done/done |
| known todo, файл переименован вручную в `.in-work` | known побеждает (todo); имя в state обновляется на `.in-work` — рассинхрон чинит doctor (10), не эта задача |
| Три `.in-work` | первый in-progress, два blocked |
| phase у demoted null | поставить `plan` |
