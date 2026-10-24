# План: 11-acceptance-pass

## Цель

Сквозная приёмка hardening + i18n: авто-прогоны, smoke install/lang, `acceptance-notes.md`, закрытие DoD эпика.

## Out of scope

- Новые фичи; dependsOn; HTML dashboard; правки вне багфиксов.

## Шаги

1. `./tests/run.sh` на текущем дереве.
2. Per-lang (`en|uk|ru`): temp tasks + `TP_LANG`, hook-followup next/resume/blocked+Recommendation, `doctor` → 0 problems.
3. Smoke install (`CURSOR_DIR`): `--lang` en/uk/ru → readlink + commit-before-done wording.
4. `acceptance-notes.md` + обновить DoD в `00-plan.done.md`.
5. CI: `gh` / локальный suite как evidence.

## DoD

- [x] авто зелёные
- [x] acceptance-notes заполнен
- [x] epic DoD / follow-ups
- [x] tests green
