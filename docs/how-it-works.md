# How cursor-pipeline works

## Phases

Each task moves through phases stored in `state.json`:

| Phase | Purpose |
|-------|---------|
| `plan` | Write `runs/<id>/plan.md` from the task file and codebase |
| `fact` | Subagent (or self) runs `tp-fact.md`; may produce `questions.md` |
| `awaiting-approval` | Optional human gate when `gateAfterFact: true` |
| `implement` | Code changes per plan |
| `check` | Subagent runs `tp-check.md` → `check-report.md` |
| `fix` | Address `fix-plan.md`; may loop to `check` up to `maxCheckRounds` |
| `commit` | Remote, checks, Docker cleanup, then one git commit; mark `done` only with that commit (rollback if commit fails) |
| `done` | Terminal status/phase after a successful git commit |

Statuses: `todo`, `in-progress`, `blocked`, `done`. Only one task may be `in-progress`.

### Language resolution

| Layer | Source order | Default |
|-------|--------------|---------|
| Agent packs (install) | `--lang` → `TP_LANG` → `~/.cursor/task-pipeline/install.json` → `en` | **`en`** |
| CLI / hooks / `run-loop` notify | `state.config.lang` → `TP_LANG` → legacy | new `init` → **`en`**; existing state without `lang` → **`ru`** |

`config.lang` is `en` | `uk` | `ru`. CLI/hook strings load from `scripts/locales/<lang>.json` via `scripts/i18n.mjs`. Agent command/rule files live under `commands/<lang>/` and `rules/<lang>/`; `./install.sh --lang …` symlinks the chosen pack into `~/.cursor/commands/` and `~/.cursor/rules/`. Changing install `--lang` does not rewrite existing `state.config.lang`.

### `questions.md` markers

| Role | EN | RU | UK |
|------|----|----|----|
| Recommendation | `Recommendation:` | `Рекомендация:` | `Рекомендація:` |
| Answer | `Answer:` | `Ответ:` | `Відповідь:` |

Auto-fill from recommendation keeps the same language label as the recommendation line.

On the commit phase the agent stays `in-progress` until `git commit` succeeds: `TP set … done` (task file rename) immediately before staging that commit; if the commit fails, roll back with `TP set … --status in-progress --phase commit --force`. Push failure does not undo `done`.

`tp-state set` validates status/phase invariants (for example `done` implies `phase=done`, `todo` implies `phase=null`) and, while status stays `in-progress`, only allows adjacent phase moves along the pipeline (`plan → fact → … → commit`, plus documented shortcuts such as `fact → implement` and `check → commit`). Use `--force` to bypass those checks for manual repair; the status/phase whitelist and the single `in-progress` rule still apply.

## File naming

`tp-state set` renames task files:

- `todo` → `001-name.md`
- `in-progress` / `blocked` → `001-name.in-work.md`
- `done` → `001-name.done.md`

Cross-references inside the task folder are rewritten automatically.

On `init`, task ids **not** already in `state.json` get status from the filename: `.done.md` → `done`, `.in-work.md` → `in-progress` (phase `plan`), plain `.md` → `todo`. Existing ids keep their stored status/phase (only the `file` field is refreshed). If several files infer as `in-progress`, the first by sorted name stays `in-progress` and the rest become `blocked` (stderr warning). Exact `blocked` cannot be recovered from the name alone — both `blocked` and `in-progress` use `.in-work.md`.

## Artifacts

Under `<tasksDir>/.pipeline/runs/<id>/`:

| File | Role |
|------|------|
| `plan.md` | Implementation plan |
| `fact-report.md` | Plan fact-check result |
| `check-report.md` | Implementation review rounds |
| `fix-plan.md` | Required fixes from review |
| `questions.md` | Human decisions; recommendation + answer markers (EN/RU/UK, see table above) |

If every question has an answer (including auto-filled from the recommendation), `tp-state next` can resume without manual `blocked` clearance.

## Hooks

Installed into `~/.cursor/hooks.json`:

1. **beforeSubmitPrompt** — remembers chats where `/task-pipeline` was invoked (`~/.cursor/task-pipeline/sessions/<conversation>.json`).
2. **afterAgentResponse** — sets `askedQuestion` when the last non-code line ends with `?`, except rhetorical pipeline “continue?” phrases.
3. **stop** — calls `tp-state hook-followup --workspace <root>` and may return `{ "followup_message": "..." }` for Cursor to send automatically (`loop_limit: 100`).

When `askedQuestion` is true and the followup is not `kind: next-task`, the hook suppresses followup and shows a notification (macOS).

## Active folder mapping

`~/.cursor/task-pipeline/active.json` maps git workspace roots to the tasks directory last used with `init` in that repo. `hook-followup` uses this to find state after a task completes.

## Batch mode (`run-loop.sh`)

Each loop iteration spawns `cursor-agent` with `TP_AUTONOMOUS=1` and the `/task-pipeline` prompt. The agent may complete only part of a task per invocation; the script retries until status changes, hits `done`, `blocked`, or stalls twice with no phase change.

Commit phase under `TP_AUTONOMOUS=1` uses **focused** tests (paths from the diff + typecheck), not full-repo precommit.

## What stays local

Never committed to git:

- `~/.cursor/task-pipeline/active.json`
- `~/.cursor/task-pipeline/sessions/`
- `<tasksDir>/.pipeline/` inside your projects
