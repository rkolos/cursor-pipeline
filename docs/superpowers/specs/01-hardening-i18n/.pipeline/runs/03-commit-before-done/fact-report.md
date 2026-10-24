# Fact-report: 03-commit-before-done

## Вердикт

План совпадает со спекой и текущим §8 (отметка done до git commit без rollback). `install.sh` уже линкует все `task-pipeline-*.mdc` — новый rule попадёт автоматически. Soft-check в tp-state пропущен по Q1/A. Блокирующих вопросов нет.

## Что исправлено

- **факт:** soft-check вынесен в out of scope с записью в questions (рекомендация A применена).
- **факт:** правка install.sh не обязательна при рабочем glob — DoD «install ставит rule» выполняется циклом.
- **конфликт:** порядок в §8 явно set done → add → commit + rollback, без второго противоречащего happy-path.

## Вопросы

Q1 — ответ A (пропуск soft-check).
