# Command /tp-check

Critical audit of an **already implemented** task against its plan for `/task-pipeline`. Plan mode not required: result is files. Usually run by a subagent; manually: `/tp-check <id>`.

## Input

- `node ~/.cursor/task-pipeline/tp-state.mjs show <id>` (or with `--dir <tasksDir>`) → `file`, `runDir`, `tasksDir`.
- Plan: `<runDir>/plan.md`.
- Implementation: uncommitted changes — `git status`, `git diff`, `git diff --staged`, new untracked files. Do not audit the tasks folder / its `.pipeline/` — that is pipeline bookkeeping.
- Project rules: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.cursor/rules/`.
- Repeat round: previous `check-report.md` and `fix-plan.md` sections — verify prior findings are actually closed.

## Hard rules

- Code is read-only. Write only `check-report.md` and `fix-plan.md` (and `questions.md` if needed) under `<runDir>`.
- Do not fix findings in this pass.
- Do not invent problems: if data is missing — open questions.
- Read-only checks allowed: lint, typecheck, focused tests for touched modules. Do not run migrations against shared DBs or start long-lived services.
- Structural questions (who calls what, what breaks) — via CodeGraph if available.

## Review priority

1. **Logical conflicts and regressions:** contradictions in new logic; conflict with existing callers and contracts; layer drift (API / DB / UI / background jobs / tests).
2. **Implementation bugs:** wrong logic, broken branches and imports; swallowed exceptions, bad defaults; failures on real data.
3. **Edge cases:** null/partial; empty lists, zero limits, already-done; unknown enums; race/retry/partial success/timeout; permissions and data isolation; backward compatibility; bounds and off-by-one. For each: handling + test, or it is a finding.
4. **Project rules** — violations are findings.
5. **Plan coverage** (secondary): each DoD item — `done` / `partial` / `not done`.

## Output

### `<runDir>/check-report.md` — append section `## Round <R>`

1. **Verdict** (2–4 sentences).
2. **Plan coverage** — DoD items with statuses.
3. **Findings** by severity (Blockers / Critical / Minor), each:
   - **Where:** file / symbol / flow
   - **What is wrong**
   - **Why it matters**
   - **“Fixed when” criterion**
4. **Open questions.**

### `<runDir>/fix-plan.md` — only if there are findings (overwrite)

Ordered tasks for **all** findings (blockers → critical → minor): files, what to do, how to verify. No “recommendations for later”. A finding that needs a product decision — a question in `questions.md` (same format as `tp-fact.md`) instead of a fix task. If the question has **Recommendation:** — fill `Answer:` with that option immediately and **do not** return `needs-answers` (keep the finding in the report marked “accepted per recommendation”, and close it via `fix-plan.md`). `needs-answers` only if there is no recommendation.

If there are no findings — delete `fix-plan.md` if left from a prior round.

### Last line of the reply

`status: clean` | `status: has-findings` | `status: needs-answers`
