# Fix-plan: 00-plan (раунд 2)

Упорядоченные задачи по findings check-report раунда 2. Только правки markdown в папке задач; продуктовый код не трогать.

## 1. [Критичный] Разрешить `commit → fix` в задаче 01

**Файл:** `docs/superpowers/specs/01-hardening-i18n/01-state-transition-validation.md`

**Сделать:**
- В §5 (допустимые смены `--phase`) добавить явный переход `commit → fix` — откат при провале проверок на фазе commit (как в `commands/task-pipeline.md` §8 п.2 / 2a).
- Сохранить уже описанные: `check → commit`, `check → fix`, `fix → commit`, `fact → implement`, `awaiting-approval → implement`, цепочку с `fix → check`.
- Не ослаблять запрет произвольных прыжков (`plan → commit`, `implement → plan` и т.п.).

**Проверить:**
- В тексте §5 есть `commit → fix`.
- Нет противоречия с инвариантом «`phase=done` при `in-progress` — fail».

## 2. [Минорный] Один канонический порядок done/commit в задаче 03

**Файл:** `docs/superpowers/specs/01-hardening-i18n/03-commit-before-done.md`

**Сделать:**
- В Description п.2 оставить один порядок: подготовка изменений → `TP set --status done --phase done` (rename) → `git add` (включая rename) → один `git commit`.
- Явный rollback при падении commit: `TP set --status in-progress --phase commit --force` (+ возврат файла к `.in-work` через set).
- Удалить формулировку «stage → git commit → при успехе → set done», чтобы не конфликтовала с практичным порядком и DoD.

**Проверить:**
- В `03` нет двух взаимоисключающих happy-path порядков.
- DoD по-прежнему: нет «done до успешного commit» без описанного rollback.
