# Spec 01 — Task 07 — English locale (commands, rules, strings)

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **07** · priority **P0**  
**Depends on:** [06](06-i18n-foundation.md), [03](03-commit-before-done.md) (commit-before-done должен попасть в EN)

## Description

Полный английский пакет для агента и CLI:

1. `commands/en/task-pipeline.md`, `tp-fact.md`, `tp-check.md` — перевод с `commands/ru/`, семантика 1:1 (включая commit-before-done, TP_AUTONOMOUS, Docker cleanup, questions format с `Recommendation:` / `Answer:`).
2. `rules/en/task-pipeline-*.mdc` — все rules из `rules/ru/` + `task-pipeline-commit-before-done.mdc`.
3. `scripts/locales/en.json` — полные строки followup/notice/fail (не stubs).
4. Пример `questions.md` в docs/examples с EN-метками.
5. Тест: `TP_LANG=en` или state.lang=en → `hook-followup` next-task followup содержит английский текст (или устойчивый ключ-фрагмент).

Не удалять `ru`. Не переводить README целиком здесь (README уже EN) — только agent/CLI surfaces.

## Files

- Create: `commands/en/*.md`, `rules/en/*.mdc`
- Modify: `scripts/locales/en.json`
- Modify: `docs/examples/tasks/*` при необходимости (остаются EN-friendly)
- Modify: tests for lang=en followup

## Pay attention

- Slash command имена файлов те же (`task-pipeline.md`) — меняется только каталог lang.
- В followup пути `~/.cursor/commands/task-pipeline.md` остаются (install symlink); не ссылаться на `commands/en/...` в followup.
- Сохранить структуру заголовков/§ чтобы агент навигировал одинаково.

## Definition of done

- [ ] Три EN commands + все EN rules существуют и эквивалентны RU по смыслу.
- [ ] `en.json` без TODO-заглушек на followup/notice.
- [ ] Тест followup на en.
- [ ] `./tests/run.sh` зелёный.
