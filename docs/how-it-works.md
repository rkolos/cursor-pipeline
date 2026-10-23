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
| `commit` | Git commit/push, Docker cleanup, mark task `done` |
| `done` | Terminal phase |

Statuses: `todo`, `in-progress`, `blocked`, `done`. Only one task may be `in-progress`.

## File naming

`tp-state set` renames task files:

- `todo` → `001-name.md`
- `in-progress` / `blocked` → `001-name.in-work.md`
- `done` → `001-name.done.md`

Cross-references inside the task folder are rewritten automatically.

## Artifacts

Under `<tasksDir>/.pipeline/runs/<id>/`:

| File | Role |
|------|------|
| `plan.md` | Implementation plan |
| `fact-report.md` | Plan fact-check result |
| `check-report.md` | Implementation review rounds |
| `fix-plan.md` | Required fixes from review |
| `questions.md` | Human decisions; `Рекомендация:` + `Ответ:` |

If every question has `Ответ:` (including auto-filled from `Рекомендация:`), `tp-state next` can resume without manual `blocked` clearance.

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
