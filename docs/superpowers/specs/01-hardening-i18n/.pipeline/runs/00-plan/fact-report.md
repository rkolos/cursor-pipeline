# Fact-report: 00-plan

## Вердикт

Эпик Hardening + i18n согласован с репозиторием: все заявленные точки касания (`scripts/`, `commands/`, `rules/`, `tests/`, `install.sh`, `docs/how-it-works.md`) на месте; задачи `01`–`11` полны (Description / Files / DoD); зависимости `06→07/08` и `01–10→11` зафиксированы. Kickoff готов к закрытию без продуктового кода; baseline `./tests/run.sh` зелёный. Блокирующих вопросов нет.

## Что исправлено

- **факт:** зафиксирована проверенная инвентаризация файлов касания и зелёный baseline на момент fact (вместо «сверить потом»).
- **факт:** уточнено, что `rewriteReferences` в `tp-state` реально обновляет `Parent plan` в соседних `.md` при rename — не «магия без кода».
- **факт:** отмечено отсутствие project-level `AGENTS.md` / `.cursor/rules/` — критерии из эпика и кода репо.
- **конфликт:** убрана двусмысленность «коммит docs + .pipeline» → явно только дерево `docs/superpowers/` (включая вложенный `.pipeline`).
- **edge case:** symlink `~/.cursor/task-pipeline` → другой clone вынесен в out of scope (не чинить из kickoff).
- **edge case / DoD:** CI (нет `.github/`) и выбор symlink/ru — out of scope, как и в эпике; DoD commit/done привязаны к автообновлению ссылок через `TP set`.
- **DoD:** шаги implement сведены к фиксации вердикта; исследование не дублировать после fact.

## Вопросы

нет
