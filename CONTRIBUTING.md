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
- `hook-followup.test.sh` — `tp-state hook-followup` branches (resume, gate, blocked, next-task)
- `install-lang.test.sh` — `install.sh --lang` / `TP_LANG` / `install.json` (temp `CURSOR_DIR`)

Requires Node.js on PATH.

## Changing agent prompts

Localized agent prompts live under `commands/<lang>/` and `rules/<lang>/` for **`en`**, **`uk`**, and **`ru`**. Install default is `en` (`./install.sh --lang …`). CLI/hook strings are in `scripts/locales/*.json` (`scripts/i18n.mjs`).

**Sync all three locales:** any meaningful change to a command or rule (new phase rule, DoD wording, marker names, followup contract) must be applied to `commands/en/`, `commands/uk/`, and `commands/ru/` (and the matching `rules/<lang>/` files). Do not leave one language pack behind. The same applies to new keys in `scripts/locales/*.json` — add the key to `en.json`, `uk.json`, and `ru.json`.

After editing:

1. Run `./tests/run.sh`
2. Smoke-test on [docs/examples/tasks](docs/examples/tasks) with `/task-pipeline` in a throwaway project (`./install.sh --lang en` or another pack)
3. If you change followup / notify string keys, note behavior-sensitive diffs in the PR

## Changing install behavior

- `install.sh` must stay idempotent
- `merge-hooks.mjs` must not remove non-pipeline hooks; re-merge **updates** existing pipeline entries (timeout / loop_limit / command) matched by marker `task-pipeline/hook.sh`
- Do not symlink `merge-hooks.mjs` into `~/.cursor/task-pipeline/`

## Pull requests

- No personal paths or private project names in the repo (`rg` for `/Users/`, internal product names)
- User-facing install/docs in English
- Apache-2.0 compatible changes only
