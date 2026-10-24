# Spec 01 — Task 11 — Acceptance pass (hardening + three locales)

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **11** · priority **P1**  
**Depends on:** [01](01-state-transition-validation.done.md)–[10](10-tp-state-doctor.md)

## Description

Сквозная приёмка эпика без изменения продуктового кода сверх фиксов багов, найденных здесь.

### Автомат

1. `./tests/run.sh` на чистом дереве.
2. Для каждого lang ∈ `en,uk,ru`:
   - temp tasks dir + `init` с `TP_LANG=<lang>` / config.lang
   - прогнать `hook-followup` сценарии next-task / resume / blocked+Recommendation
   - `doctor` на здоровом state → 0 problems
3. `merge-hooks` update тест уже в suite — подтвердить.
4. CI workflow зелёный на default branch (если push доступен — иначе локально достаточно).

### Ручной smoke (чеклист в артефакте)

Создать `docs/superpowers/specs/01-hardening-i18n/acceptance-notes.md` (или `.pipeline/runs/…` если идёт через pipeline) со статусом:

- [ ] `./install.sh --lang en` → Reload → `/task-pipeline docs/examples/tasks` проходит хотя бы plan→fact на smoke (или полный mini cycle если время есть)
- [ ] Переключение `--lang uk` / `ru` меняет текст commands в `~/.cursor/commands/task-pipeline.md` (readlink + head)
- [ ] Риторический «Continue?» не стопорит next-task (уже unit; IDE optional)
- [ ] Commit-before-done: в установленном `task-pipeline.md` нет инструкции «set done до git commit» без rollback

Баги, найденные в acceptance и in-scope эпика — фиксить тут же. Out-of-scope — одна строка в `docs/…` backlog или issue, не в nlo вечном.

## Files

- Create: `docs/superpowers/specs/01-hardening-i18n/acceptance-notes.md` (результаты прогона)
- Modify: только bugfix files по факту

## Pay attention

- Не расширять scope (dependsOn, HTML dashboard и т.д.).
- Документ acceptance — факт текущего прогона, без истории «раньше падало».

## Definition of done

- [ ] Все авто-проверки выше зелёные.
- [ ] `acceptance-notes.md` заполнен чеклистом (pass/fail + дата).
- [ ] Эпик 00-plan DoD выполнен или явные остатки записаны как out-of-scope follow-ups (не как «почти»).
- [ ] `./tests/run.sh` зелёный.
