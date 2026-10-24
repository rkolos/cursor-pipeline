# Spec 01 — Task 05 — `hook-followup` tests + GitHub Actions

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **05** · priority **P0**  
**Depends on:** [01](01-state-transition-validation.done.md), [02](02-init-infer-status-from-filename.md) (для реалистичного state)

## Description

Расширить покрытие критического пути stop-hook state:

1. В `tests/tp-state.test.sh` (или новый `tests/hook-followup.test.sh`) покрыть `hook-followup --workspace`:
   - active `in-progress` + phase `implement` → JSON с `followup`, без `kind: next-task`
   - phase `awaiting-approval` → `notice`, без `followup`
   - `blocked` без ответов → `notice` про questions.md
   - `blocked` + Recommendation/Ответ заполнены → `followup` на resume
   - last done + next todo + `continueNextTask: true` → `kind: next-task`
   - `continueNextTask: false` → notice без followup next-task
2. Лёгкий тест `hook.mjs stop` с fake session + temp workspace (optional): если слишком хрупко к Cursor payload — ограничиться `tp-state hook-followup`.
3. Добавить `.github/workflows/test.yml`: on push/PR → `ubuntu-latest`, Node 20, `./tests/run.sh`.

## Files

- Modify or Create: `tests/tp-state.test.sh` / `tests/hook-followup.test.sh`
- Modify: `tests/run.sh`
- Create: `.github/workflows/test.yml`
- Modify: `README.md` — badge optional, строка про CI

## Pay attention

- Тесты не должны писать в реальный `~/.cursor/task-pipeline/active.json` пользовательской машины без изоляции: использовать temp HOME или передавать workspace так, чтобы active писался в temp. Предпочтительно: в тесте выставлять `HOME="$TMP"` или патч через env, если добавите `TP_HOME` (минимальный opt-in в `tp-state` / `hook` — допустим в этой задаче).
- Не флакать на locale (пока RU strings).

## Definition of done

- [ ] Все перечисленные ветки `hook-followup` покрыты assert’ами.
- [ ] CI workflow запускает `./tests/run.sh`.
- [ ] Локально `./tests/run.sh` зелёный с чистым temp HOME.
