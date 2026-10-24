# Acceptance notes — Spec 01 (hardening + i18n)

**Date:** 2026-10-24  
**Tree:** `main` @ acceptance of task `11-acceptance-pass`  
**Runner:** batch `/task-pipeline` (headless; IDE Reload not performed)

## Automated

| Check | Result |
|-------|--------|
| `./tests/run.sh` | **pass** |
| `merge-hooks` (suite) | **pass** |
| CI `test` workflow on `main` (latest runs for 06–10) | **pass** (GitHub Actions success) |
| Per-lang `en` / `uk` / `ru`: `TP_LANG` init → `config.lang` | **pass** |
| Per-lang: `doctor` on healthy state → exit 0, empty `problems` | **pass** |
| Per-lang: `hook-followup` `kind=next-task` | **pass** |
| Per-lang: in-progress → resume `followup` (no `kind`) | **pass** |
| Per-lang: blocked + Recommendation/Рекомендація/Рекомендация → unblock | **pass** |
| `CURSOR_DIR` `./install.sh --lang en\|uk\|ru` → symlink into `commands/<lang>/` | **pass** |
| Installed `task-pipeline.md` includes done→commit + `--force` rollback | **pass** |
| `docs/examples/tasks` CLI plan→fact→implement | **pass** (`001-add-changelog`) |

## Manual / smoke checklist

- [x] `./install.sh --lang en` → command pack switches (verified via isolated `CURSOR_DIR`; full Cursor **Reload Window** + live `/task-pipeline` UI not run in this batch — CLI surrogate above covers plan→fact)
- [x] `--lang uk` / `ru` changes text of `task-pipeline.md` (readlink + head: EN “Command”, UK “Команда … тека”, RU “Команда … папка”)
- [x] Rhetorical “Continue?” does not block next-task (unit `hook-question.test.sh` + suite)
- [x] Commit-before-done: installed/repo commands require `set done` immediately before `git commit` **with** rollback `--force` on failure — no “done without rollback” instruction

## Epic DoD (`00-plan`)

| Item | Status |
|------|--------|
| Tasks 01–11 done | **met** at close of this task |
| `./tests/run.sh` green in CI | **met** |
| `lang=en\|uk\|ru` followup + questions auto-unblock | **met** |
| Reinstall updates hooks; `doctor` catches file↔status | **met** (04 + 10 + this pass) |
| README `--lang` and defaults | **met** (09) |

## Out-of-scope follow-ups

None for this epic. Optional later (not blockers): live IDE Reload smoke by a human after `./install.sh --lang …` on a real `~/.cursor`.
