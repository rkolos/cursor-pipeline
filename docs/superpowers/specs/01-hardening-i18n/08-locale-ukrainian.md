# Spec 01 — Task 08 — Ukrainian locale (commands, rules, strings)

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **08** · priority **P0**  
**Depends on:** [06](06-i18n-foundation.done.md), [07](07-locale-english.md) (можно переводить с EN как с канона открытого репо)

## Description

Полный український пакет:

1. `commands/uk/task-pipeline.md`, `tp-fact.md`, `tp-check.md` — повний переклад (з EN або RU), семантика 1:1.
2. `rules/uk/task-pipeline-*.mdc` — усі rules.
3. `scripts/locales/uk.json` — followup/notice/fail українською.
4. У `questions.md` агент з `lang=uk` пише `Рекомендація:` / `Відповідь:` (парсер уже приймає з 06).
5. Тест: state.lang=`uk` → followup містить український фрагмент.

Мова UI Cursor не важлива — важливі тексти, які читає/пише агент.

## Files

- Create: `commands/uk/*.md`, `rules/uk/*.mdc`
- Modify: `scripts/locales/uk.json`
- Modify: tests for lang=uk

## Pay attention

- Не змішувати російські кальки без потреби; терміни pipeline (`plan`, `fact`, `commit`, `blocked`) можна лишати як loanwords у дужках при першій згадці, далі — стабільно одним варіантом.
- Шляхи `~/.cursor/commands/task-pipeline.md` у followup — як в EN/RU.
- Після перекладу звірити чекліст з 07 (Docker cleanup, autonomous checks, commit-before-done, no-stop).

## Definition of done

- [ ] Три UK commands + усі UK rules.
- [ ] `uk.json` повний для followup/notice/fail.
- [ ] Тест followup на uk.
- [ ] `./tests/run.sh` зелений.
