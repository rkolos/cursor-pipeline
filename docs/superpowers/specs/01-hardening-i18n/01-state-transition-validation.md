# Spec 01 — Task 01 — Validate status/phase transitions in `tp-state set`

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **01** · priority **P0**  
**Depends on:** —

## Description

В `tp-state.mjs` `cmdSet` сегодня принимает любую комбинацию `status`/`phase` из whitelist списков. Добавить проверку **допустимых переходов** и инвариантов:

1. `status=done` ⇒ `phase` должен быть `done` (или выставляться автоматически в `done`, если `--phase` не передан).
2. `status=todo` ⇒ `phase` только `null`.
3. `status=blocked` ⇒ `phase` ∈ рабочие фазы (`plan|fact|awaiting-approval|implement|check|fix|commit`), не `done`, не `null` без явного сохранения предыдущей (если `--phase` не передан — оставить текущую; если текущая `null`/`done` — fail).
4. `status=in-progress` ⇒ `phase` ∈ `PHASES` без терминального-только смысла: разрешены все кроме требования «сразу done»; `phase=done` при `in-progress` — fail.
5. Смена только `--phase` при `status=in-progress`: разрешать соседние/ожидаемые фазы пайплайна:

   `null|plan → fact → awaiting-approval → implement → check → fix → check → commit → done`  
   Допустимы также: `check → commit` (clean / без fix-plan), `check → fix` (findings / `has-findings`), `fix → commit` (после max rounds), `commit → fix` (провал проверок на фазе commit), `fact → implement` (без gate), `awaiting-approval → implement`.  
   Запретить произвольные прыжки вроде `plan → commit`, `implement → plan` (без `force`).

6. Опциональный флаг `--force` на `set` обходит transition check (для ручного ремонта); в stderr однострочное предупреждение.

Сообщения `fail(...)` пока на русском (локаль строк — задача 06); текст ясный: какая пара запрещена и что ожидалось.

## Files

- Modify: `scripts/tp-state.mjs` (`cmdSet`, helpers `assertTransition` / `allowedPhases`)
- Modify: `tests/tp-state.test.sh` — кейсы fail (ожидать exit ≠ 0) и happy path `plan→fact→…`
- Modify: `docs/how-it-works.md` — короткий абзац про валидацию (EN)

## Pay attention

- Не ломать `hook-followup` и `next`: они не вызывают незаконные set сами.
- Один `in-progress` — уже есть; не дублировать логику.
- `phase=null` передаётся как `--phase null` (уже есть).

## Definition of done

- [ ] Нелегальный `set` завершается кодом 1 и понятным stderr.
- [ ] Легальный полный цикл фаз в тесте проходит.
- [ ] `--force` позволяет аварийный set.
- [ ] `./tests/run.sh` зелёный.
