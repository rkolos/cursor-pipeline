# Spec 01 — Task 02 — `init`: restore status from filename suffixes

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **02** · priority **P0**  
**Depends on:** [01](01-state-transition-validation.done.md) (желательно; можно параллельно, если не трогать одни и те же ветки `cmdSet`)

## Description

Сейчас при **новой** записи в state (нет id в предыдущем `state.json`) статус берётся так:

- `*.done.md` → `done`
- иначе → `todo`

из-за этого `001-foo.in-work.md` после потери `.pipeline/state.json` становится `todo` при живом `.in-work` файле.

Исправить `cmdInit`:

| Filename pattern | status | phase |
|---|---|---|
| `*.done.md` | `done` | `done` |
| `*.in-work.md` | `in-progress` | `plan` если phase неизвестна; если в старом state был phase — сохранить из `known` |
| plain `*.md` | `todo` | `null` |

Если после infer получилось **больше одной** `in-progress` — оставить первую по sort имени, остальные перевести в `blocked` с тем же phase (или `plan`), stderr warning со списком id. Не `fail` весь init (чтобы doctor/repair был возможен).

`known` из previous state по-прежнему побеждает для существующих id (file path обновляется).

## Files

- Modify: `scripts/tp-state.mjs` (`cmdInit`, helper `statusFromFileName`)
- Modify: `tests/tp-state.test.sh` — temp dir с `.in-work.md` без state → init → status in-progress
- Modify: `docs/how-it-works.md` — File naming / recovery note

## Pay attention

- `blocked` тоже использует суффикс `.in-work` — отличить blocked от in-progress **только из имени нельзя**. Для recovery без state: считать `.in-work` → `in-progress`. Документировать: точный `blocked` без state не восстанавливается (doctor может подсказать смотреть `questions.md`).
- Не переименовывать файлы в init, только выставить status под текущее имя (или после sync — если status todo а файл `.in-work`, либо rename к todo, либо status→in-progress; **выбрать status→in-progress**, не трогая имя).

## Definition of done

- [ ] Тест: папка с `001-a.in-work.md` + `002-b.md`, без state → init → `001` in-progress, `002` todo.
- [ ] Тест: два `.in-work` → один in-progress, второй blocked (или документированное поведение), init exit 0.
- [ ] Existing state с known id не затирает status.
- [ ] `./tests/run.sh` зелёный.
