# Contributing

Thanks for improving cursor-pipeline.

## Tests

From the repo root:

```bash
./tests/run.sh
```

- `hook-question.test.sh` — `askedQuestion` heuristic (rhetorical “continue?” vs real questions)
- `tp-state.test.sh` — `init` / `next` / `set` / `hook-followup` / auto-unblock from `Рекомендация:`
- `merge-hooks.test.sh` — merge/update/uninstall of pipeline hooks without touching others

Requires Node.js on PATH.

## Changing agent prompts

Files under `commands/` and `rules/` drive agent behavior. After editing:

1. Run `./tests/run.sh`
2. Smoke-test on [docs/examples/tasks](docs/examples/tasks) with `/task-pipeline` in a throwaway project
3. If you change Russian followup strings in `tp-state.mjs` or `hook.mjs`, note it in the PR — behavior-sensitive

## Changing install behavior

- `install.sh` must stay idempotent
- `merge-hooks.mjs` must not remove non-pipeline hooks; re-merge **updates** existing pipeline entries (timeout / loop_limit / command) matched by marker `task-pipeline/hook.sh`
- Do not symlink `merge-hooks.mjs` into `~/.cursor/task-pipeline/`

## Pull requests

- No personal paths or private project names in the repo (`rg` for `/Users/`, internal product names)
- User-facing install/docs in English
- Apache-2.0 compatible changes only
