# Command /tp-fact

Fact-check of a task plan that is **not yet implemented**, for `/task-pipeline`. Plan mode not required: input and output are files. Usually run by a subagent; manually: `/tp-fact <id>` (tasks folder is the active one — see `node ~/.cursor/task-pipeline/tp-state.mjs show <id>`).

## Input

- `node ~/.cursor/task-pipeline/tp-state.mjs show <id>` (or with `--dir <tasksDir>`) → `file`, `runDir`.
- Plan: `<runDir>/plan.md`. If missing — return `status: no-plan`.
- Task file and everything it references.
- Project rules: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.cursor/rules/`, specs/docs they point to.

## Goal (all at once)

1. Fact-check the plan against real code, specs, and the task file.
2. Logical conflicts inside the plan and with existing behavior.
3. Unclosed edge cases.
4. Completeness and testability of DoD.
5. **Fix the plan immediately** — rewrite `plan.md` entirely (coherent text, not a list of notes).

## Hard rules

- Change only `plan.md`, `fact-report.md`, and if needed `questions.md` under `<runDir>`. Do not touch project code, configs, tests, or docs.
- Do not expand scope. Close gaps minimally: a step, explicit out-of-scope, or a question.
- Do not invent APIs, files, flags, contracts — verify. Structural questions — via CodeGraph if available.
- Optional (“later”, “nice to have”) must not be dropped silently: put in steps/DoD, explicit out-of-scope with rationale, or a question.
- Project rules are mandatory fact-check criteria.

## 1) Fact-check

- files, symbols, routes exist and do what is claimed;
- contracts (API, schemas, events) match project specs;
- “already exists” / “write from scratch” is true;
- the plan rests on prior tasks’ real code, not their descriptions;
- steps do not change what the plan itself forbade touching.

False facts — fix in the step text.

## 2) Logical conflicts

Step A vs step B; “don’t touch X” vs a step that changes X; two sources of truth without a winner rule; conflict with existing callers; mutually exclusive “just in case” approaches; DoD without a step and a step without a criterion. Pick a coherent variant and rewrite; do not mark “keep in mind”.

## 3) Edge cases

Only applicable ones: empty/null/partial data; external call errors, retry, partial success, timeouts; races and at-least-once delivery; permissions/tenant isolation; limits and off-by-one; data/API backward compatibility; migration idempotency. Each — a step + DoD criterion or explicit out-of-scope.

## 4) DoD completeness

In the final `plan.md`: goal in one paragraph; **Out of scope**; steps with concrete files; **DoD** — “done when …”; **How to verify** — concrete project commands; every in-scope edge case reflected in acceptance.

## Product forks

If a choice cannot be derived from code, task, and docs — do not decide silently. Append to `<runDir>/questions.md`:

```markdown
## Q<n>: <question>
Context: …
Options: A) … — consequences; B) … — consequences
Recommendation: A
Answer:
```

- If **Recommendation:** is present (letter/token) — write it into `Answer:` immediately and **apply it in the plan**. This is not `needs-answers`: do not block the task.
- `status: needs-answers` — **only** if the question has no recommendation and empty `Answer:` (still fix the rest of the plan).
- Already filled `Answer:` — apply in the plan; do not ask again.

## Output

1. Rewritten `plan.md`.
2. `fact-report.md`: **Verdict** (2–4 sentences); **What was fixed** — bullets “fact / conflict / edge case / DoD”; **Questions** — links to Q<n> or “none”.
3. Last line of the reply: `status: ok` or `status: needs-answers`.
