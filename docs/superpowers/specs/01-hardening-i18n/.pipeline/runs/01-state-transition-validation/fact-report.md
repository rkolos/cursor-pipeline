# Fact-report: 01-state-transition-validation

## Вердикт

План согласован с `cmdSet` / `parseArgs` / whitelist в `scripts/tp-state.mjs` и со спекой: валидации переходов сейчас нет, `--force` нет, `parseArgs` всегда ждёт значение у флага. Граф `PHASE_NEXT` покрывает контракт агента (`fact→implement`, `check→commit`/`fix`, `commit→fix`). Существующий тест `plan→done` — смена **status**, не phase-adjacency; останется валидным. Блокирующих вопросов нет.

## Что исправлено

- **факт:** уточнено в плане — adjacency только при неизменном `in-progress`; смена status (в т.ч. `done`/`blocked`/`todo`) проверяется инвариантами 1–4 + auto phase.
- **факт:** существующий happy path теста `in-progress/plan → done/done` не ломается; полный цикл фаз — **дополнительный** блок, не замена unblock-теста.
- **конфликт:** убрана двусмысленность «force обходит всё» → force пропускает только transition/инварианты пар; whitelist `STATUSES`/`PHASES` и «один in-progress» остаются.
- **edge case:** `todo → in-progress` с любой рабочей phase (в т.ч. `commit`) без force — допускается (вход в середину); adjacency не применяется при смене status.
- **DoD:** явный критерий — stderr fail содержит запрещённый переход или нарушенный инвариант.

## Вопросы

нет
