# Command /task-pipeline [tasks-folder]

Universal task conveyor for **any** project. The folder holds task descriptions (`*.md`); file names set execution order (`001-…`, `002-…`). Each task runs:

**plan → plan fact-check → implement → implementation review → fix-plan → commit/push → mark done**.

Works in **Agent mode** (Plan mode not required). After a task closes, the stop-hook **starts** the next one in the same chat (`config.continueNextTask`, default `true`). A new chat / re-run of `/task-pipeline` is needed only for `blocked`, exhausted context, or `continueNextTask: false`.

## State

Script: `node ~/.cursor/task-pipeline/tp-state.mjs` (hereafter `TP`). Run from the workspace root.

- `TP init <folder>` — create/sync `<folder>/.pipeline/state.json` (new task files are appended as `todo`; existing statuses kept) and make the folder active for this workspace.
- `TP next` — what to do next: `resume` | `start` | `blocked` | `all-done`.
- `TP show <id|prefix>`, `TP set <id|prefix> --status S --phase P`, `TP summary`.

Statuses: `todo | in-progress | blocked | done`. Phases: `plan | fact | awaiting-approval | implement | check | fix | commit | done`. Change status/phase **only** via `TP set` — auto-continue (stop-hook) and batch mode depend on it.

Status is reflected in the task file name: `001-foo.md` → `001-foo.in-work.md` (in-progress and blocked) → `001-foo.done.md`. `TP set` renames the file and rewrites references in `.md`/`.json` in the tasks folder. Always take the task file path from `TP show <id>` (`file`); `id` (name without suffix) does not change. Do not rename task files by hand.

Task artifacts — `<folder>/.pipeline/runs/<id>/`: `plan.md`, `fact-report.md`, `check-report.md`, `fix-plan.md`, `questions.md`.

Settings — `config` in `state.json` (editable by hand):

- `gateAfterFact` (default `false`) — after fact-check, pause for plan approval;
- `maxCheckRounds` (`2`) — max review rounds;
- `push` (`true`) — push after commit;
- `reviewModel` (`null`) — model for fact/check subagents; `null` — same as current chat;
- `continueNextTask` (`true`) — after `done`, stop-hook starts the next todo in the same chat; `false` — notice only and a new chat with `/task-pipeline`;
- `lang` (`en` | `uk` | `ru`) — CLI/hook locale strings.

If the request includes `TP_AUTONOMOUS=1` (batch `~/.cursor/task-pipeline/run-loop.sh`) — `gateAfterFact` is ignored.

## 0. Start

1. If a folder is given — `TP init <folder>`. If not — `TP next`; if the script says there is no active folder, ask the user for a folder and stop.
2. From `TP next`:
   - `all-done` — say all tasks are closed, stop;
   - `blocked` — read the task’s `questions.md`. If a question has **Recommendation:** and empty `Answer:` — write the recommendation into `Answer:` (do not ask the user). If **all** questions have `Answer:` (including auto from recommendation) — `TP set <id> --status in-progress` (phase kept) and continue. Otherwise show unanswered questions without recommendation and stop;
   - `start` — `TP set <id> --status in-progress --phase plan`;
   - `resume` — continue from the current phase; read existing artifacts; do not redo finished phases.
3. Tell the user in one line: task (`position`), phase you start from.

## 1. Project context (at the start of each task)

The scheme does not know the project — discover and keep in mind across phases:

- project rules: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.cursor/rules/`, `CONTRIBUTING.md` — they override this command’s defaults;
- how to verify code: scripts in `package.json` / `Makefile` / `pyproject.toml` / `Cargo.toml` / CI (lint, typecheck, test, build);
- whether the project has its own commit procedure (command under `.cursor/commands/` with “commit” in the name, a rule, or a docs section);
- where deferred work should go (todo/backlog from rules). If nowhere — `<folder>/.pipeline/todo.md`;
- the tasks folder may have its own status index (README, `_index.json`, etc.) — update it when closing a task, keeping the format.

## 2. phase = plan

1. Read the task file fully and everything it links (roadmap, specs, dependent neighbor tasks).
2. Gather code context: CodeGraph if available (`codegraph_context` → one `codegraph_explore`), else semantic/text search. If the task builds on prior tasks — check their real code, not the description.
3. Write `runs/<id>/plan.md`:
   - **Goal** — one paragraph;
   - **Out of scope**;
   - **Steps** — concrete files/symbols (new and changed);
   - **DoD / acceptance** — observable “done when …”;
   - **How to verify** — concrete project commands and a manual scenario if needed;
   - **Edge cases** — each linked to a DoD item.
4. `TP set <id> --phase fact`.

## 3. phase = fact

1. Launch a **subagent** (Task, `subagent_type: generalPurpose`, model — `reviewModel` if set) with prompt:
   > Read `~/.cursor/commands/tp-fact.md` and follow it. Workspace: `<workspace>`. Tasks folder: `<tasksDir>`. Task: `<id>`. Last line: return status.
2. If subagents are unavailable — run `tp-fact.md` yourself, **re-reading** plan and code as an independent reviewer.
3. Result:
   - `status: needs-answers` → if every question has `Recommendation:` or a non-empty `Answer:` — fill empty `Answer:` from recommendation, **do not** set `blocked`, continue as `ok`. Else `TP set <id> --status blocked`, show questions without recommendation, stop;
   - `status: ok`, `gateAfterFact: true` and no `TP_AUTONOMOUS=1` → `TP set <id> --phase awaiting-approval`; show a short plan summary and fact-check verdict, ask “plan OK — continue?”, stop;
   - else → `TP set <id> --phase implement`.

## 4. phase = awaiting-approval

User message “ok / go / /task-pipeline” in this phase confirms the plan. If the user gave edits — apply them to `plan.md`. `TP set <id> --phase implement`.

## 5. phase = implement

1. Implement `plan.md` step by step, following project rules.
2. Checks — related to the changes (lint/typecheck, focused tests). Full suite is optional unless project rules require otherwise.
3. Stop processes started for verification (servers, workers) before the phase ends.
4. If this phase ran tests/testcontainers/`docker compose` — run **Docker cleanup** immediately (see § “Docker cleanup”).
5. Deferred work outside task scope — one line where the project says (see §1).
6. Product fork not settled in the plan → question in `questions.md`. If there is **Recommendation:** — fill `Answer:`, apply it, continue (not `blocked`). `blocked` only if there is no recommendation.
7. `TP set <id> --phase check`.

## 6. phase = check

1. Round number `R` = count of `## Round` / `## Раунд` sections in `check-report.md` + 1.
2. Launch a **subagent** (as in fact) with prompt:
   > Read `~/.cursor/commands/tp-check.md` and follow it. Workspace: `<workspace>`. Tasks folder: `<tasksDir>`. Task: `<id>`. Round: `<R>`. Last line: return status.
3. If subagents are unavailable — run `tp-check.md` yourself, re-reading the diff.
4. Result:
   - `status: clean` → `TP set <id> --phase commit`;
   - `status: needs-answers` → same rule as fact: recommendation → fill `Answer:` and do not block; else `blocked`;
   - `status: has-findings` → `TP set <id> --phase fix`.

## 7. phase = fix

1. Implement **all** of `fix-plan.md` (blockers → critical → minor), verifying each item.
2. If fixes re-ran Docker/testcontainers tests — run **Docker cleanup** (see § “Docker cleanup”).
3. If `R < maxCheckRounds` → `TP set <id> --phase check`.
4. Else: if blockers/critical remain after fixes — question in `questions.md`; with recommendation fill `Answer:` and go to `commit`; without recommendation — `blocked`. If no blockers — `TP set <id> --phase commit`.

## 8. phase = commit

If the project has its own commit procedure — follow it, filling gaps with the steps below. **Exception:** with `TP_AUTONOMOUS=1` (batch `run-loop.sh`) full project commit checks **are not** run — see §2a; other commit/push steps from the project procedure remain.

For the whole phase until a successful `git commit`, task status is `in-progress`, phase is `commit`. Do not treat the task as closed until commit succeeds.

1. **Remote:** `git fetch origin`. If the branch is behind `origin/<branch>` — list remote commits (hash, author, subject) and `git merge origin/<branch>`. Conflict → `git merge --abort`, describe in `questions.md`, `TP set <id> --status blocked`, stop.
2. **Checks:**
   - **Normal mode** (no `TP_AUTONOMOUS=1`): all project checks (lint, typecheck, test, build — whatever exists / the commit procedure requires). Failure → fix and retry; if stuck → `TP set <id> --phase fix`, describe in `fix-plan.md`, stop with a report.
   - **`TP_AUTONOMOUS=1` (required, §2a):** only **focused** checks for this task’s changes — see below. Full suite **forbidden**.
3. **Docker cleanup (required):** before the final commit — always run § “Docker cleanup”, even if this task “did not use Docker”. Do not skip.
4. **Chat summary** (do not wait for a reply): branch, file count, 2–5 bullets of substance, draft message.
5. **One commit including task rename:**
   1. Prepare all task changes (code, docs, tasks-folder index if needed).
   2. `TP set <id> --status done --phase done` (rename `.in-work` → `.done`, rewrite refs).
   3. `git add` only your work: task files, deferred-work file (if changed), tasks folder with `.pipeline/` (so rename is included). No secrets or unrelated uncommitted files.
   4. `git commit` with a message matching `git log -10 --oneline` style and a link to `<id>`.
6. **If `git commit` failed** after step 5.2: immediately `TP set <id> --status in-progress --phase commit --force` (file back to `.in-work`), describe in `fix-plan.md`, stay in phase `commit` (or go to `fix` per check rules). Task is **not** done.
7. **`git push`** if `push: true`. Push failure does **not** undo done: write deferred todo and mention in the summary. Project “after push” steps likewise do not undo done.

### 2a. Checks under `TP_AUTONOMOUS=1` (run-loop)

Goal — avoid a full suite on every batch task.

**Forbidden** (even if `/commit`, `precommit-check`, or project analog says so):

- `npm run precommit-check` (and any “lint+test+typecheck+build” one-liner);
- full `npm run test` / `npm test` across the repo;
- full `npm run lint` across the repo;
- full `npm run build` “just in case”.

**Required minimum:**

1. Focused tests for touched modules/files (jest paths to `*.spec.ts` / dirs from the task diff; e2e only if the task is explicitly about e2e).
2. `npm run typecheck` (or project equivalent), if the script exists.

Minimum failure → fix in task scope and retry; if stuck → `TP set <id> --phase fix`, describe in `fix-plan.md`, stop with a report.

In the commit summary state that a **focused** check ran (which jest paths + typecheck), not full precommit.

## 9. Wrap-up

Short: task closed, `git log -1 --format='%h %s'`, what was verified, Docker cleanup result (reclaimed space / what was kept), what was deferred, which task is next (`TP next`). **Do not** start the next task in this same turn — stop after wrap-up: with `continueNextTask: true` the stop-hook sends a followup for the next todo; with `false` or `all-done` — tell the user (new chat `/task-pipeline` only if the hook will not continue).

End wrap-up with an **assertion**, not a question: “Next in the pipeline — `<id>`.” Do not ask “Continue?”, “Go to the next?”, “Continue in this chat?” — `state.json` already answers that, and a trailing `?` can make the stop-hook treat it as a human question and stall the conveyor.

## Docker cleanup

**Required** at the end of work on a task (commit phase, step 3) and right after any Docker-backed test run in `implement`/`fix`. Goal — remove leftover test containers (testcontainers, etc.) without touching a live dev stack.

Safe commands (in order):

```bash
docker container prune -f
docker image prune -f
docker builder prune -f
# Only anonymous testcontainers volumes (64-hex). Do not touch named volumes (postgres_data / redis_data / …).
docker volume ls -q | while read -r v; do
  [ -z "$v" ] && continue
  echo "$v" | grep -qE '^[0-9a-f]{64}$' && docker volume rm "$v" 2>/dev/null || true
done
```

Before prune, ensure you **do not** stop or remove containers in `Up` status (compose names like `*-postgres-*`, `*-redis-*`, project dev stack).

Forbidden without an explicit user request: `docker system prune -a`, full `docker volume prune` (can hit named dev DB volumes), `docker stop`/`docker rm` on running containers. Removing **only** anonymous hash volumes (`^[0-9a-f]{64}$`) is allowed and required.

If `docker` is unavailable — one line in wrap-up: cleanup skipped (no docker); do not block the task.

In wrap-up briefly: how much removed / `Total reclaimed space`, which containers were kept on purpose.

## Conveyor rules

- Do not take product decisions silently **without a record**: write them in `questions.md` with options. If **Recommendation:** is present — write it into `Answer:` immediately and continue; **`blocked` only if there is no recommendation**.
- Questions for the user (no recommendation): `questions.md` + `blocked`. If a short question fits better in chat — ask it as the **last line of the reply, ending with `?`**, and stop. Do not ask mid-reply while continuing work.
- Terminals: run commands blocking in the current session; background processes (servers, watch) only if required to verify the task, and stop them in the same phase.
- **Docker cleanup is required** when finishing a task (commit phase) and after Docker test runs — see § “Docker cleanup”. Do not close the task without it (except “docker unavailable”).
- The commit includes renaming the task file (`.in-work.md` → `.done.md`) — stage the whole tasks folder so git sees the rename.
- Only one `in-progress` at a time (the script enforces this).
- Do not skip phases or edit `state.json` by hand during work.
- Project rules and explicit user instructions override this command’s defaults.
