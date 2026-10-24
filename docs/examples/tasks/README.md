# Example task folder

Minimal two-task pipeline to verify install on a new machine.

## Try it

1. Copy or point `/task-pipeline` at this directory from any git repo root.
2. Use Agent mode. The agent should complete `001-add-changelog` then `002-add-license-badge` (or mark docs-only tasks done per your project rules).
3. Check `.pipeline/state.json` and renamed `*.done.md` files.

Tasks are intentionally small and safe for empty repos.

For English `questions.md` markers (`Recommendation:` / `Answer:`), see [../questions.en.md](../questions.en.md).
