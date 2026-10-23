#!/usr/bin/env bash
# askedQuestion heuristic: rhetorical pipeline questions must not block followup.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/scripts/hook.sh"
SESSIONS_DIR="${HOME}/.cursor/task-pipeline/sessions"
CID="tp-test-question-$$"
SESSION_FILE="$SESSIONS_DIR/${CID}.json"

fail=0

check() {
  local want="$1"
  local text="$2"
  echo "{\"conversation_id\":\"$CID\",\"text\":$(printf '%s' "$text" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}" \
    | "$HOOK" response >/dev/null
  local got
  got="$(python3 -c "import json; print(str(json.load(open('$SESSION_FILE'))['askedQuestion']).lower())")"
  if [[ "$got" == "$want" ]]; then
    echo "  ok ($got): ${text: -72}"
  else
    echo "  FAIL (got $got, want $want): ${text: -72}"
    fail=1
  fi
}

echo "hook-question.test.sh"

echo "{\"conversation_id\":\"$CID\",\"prompt\":\"/task-pipeline x\",\"workspace_roots\":[]}" \
  | "$HOOK" prompt >/dev/null

check false "**Next:** \`06-api-vacancies-list\` (\`TP next\` → \`start\`). Continue the pipeline?"
check false "**Phase A done.** Next task: **07-web-vacancy-primitives**. Continue in this chat?"
check false "Next: plan.md → fact → implement (CRUD \`VacancyNote\`). Continue **03** in this chat?"
check false "Task done. Move to the next task?"
check false "Shall I proceed to the next task?"
check false "Task closed. Next — 08-web-add-people-dialog."
check true "Refresh the page. Need a separate commit for this fix?"
check true "Which option: A (jsonb) or B (separate table)?"

rm -f "$SESSION_FILE"

if [[ "$fail" -ne 0 ]]; then
  echo "hook-question.test.sh FAILED"
  exit 1
fi
echo "hook-question.test.sh OK"
