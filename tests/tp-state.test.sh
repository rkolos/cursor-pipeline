#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="node $REPO_ROOT/scripts/tp-state.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP"
cat > "$TMP/001-alpha.md" <<'EOF'
# 001-alpha

## Definition of done
- Example task one complete.
EOF
cat > "$TMP/002-beta.md" <<'EOF'
# 002-beta

## Definition of done
- Example task two complete.
EOF

echo "tp-state.test.sh"

$TP init "$TMP" >/dev/null

next="$($TP next --dir "$TMP")"
action="$(echo "$next" | python3 -c 'import json,sys; print(json.load(sys.stdin)["action"])')"
[[ "$action" == "start" ]] || { echo "FAIL: expected start, got $action"; exit 1; }

id="$(echo "$next" | python3 -c 'import json,sys; print(json.load(sys.stdin)["task"]["id"])')"
[[ "$id" == "001-alpha" ]] || { echo "FAIL: expected 001-alpha"; exit 1; }

$TP set "$id" --status in-progress --phase plan --dir "$TMP" >/dev/null
[[ -f "$TMP/001-alpha.in-work.md" ]] || { echo "FAIL: missing in-work rename"; exit 1; }

$TP set "$id" --status done --phase done --dir "$TMP" >/dev/null
[[ -f "$TMP/001-alpha.done.md" ]] || { echo "FAIL: missing done rename"; exit 1; }

follow="$($TP hook-followup --workspace "$TMP")"
kind="$(echo "$follow" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("kind",""))')"
[[ "$kind" == "next-task" ]] || { echo "FAIL: expected kind next-task, got $kind"; echo "$follow"; exit 1; }

RUN_DIR="$TMP/.pipeline/runs/002-beta"
mkdir -p "$RUN_DIR"
cat > "$RUN_DIR/questions.md" <<'EOF'
## Q1
Варианты: A / B
Рекомендация: A
Ответ:

EOF

$TP set 002-beta --status blocked --phase implement --dir "$TMP" >/dev/null
unblock="$($TP next --dir "$TMP")"
ub_action="$(echo "$unblock" | python3 -c 'import json,sys; print(json.load(sys.stdin)["action"])')"
[[ "$ub_action" == "resume" ]] || { echo "FAIL: expected resume after recommendation, got $ub_action"; exit 1; }

# Full legal phase cycle after unblock (status already in-progress, phase implement)
$TP set 002-beta --phase check --dir "$TMP" >/dev/null
$TP set 002-beta --phase commit --dir "$TMP" >/dev/null
$TP set 002-beta --status done --phase done --dir "$TMP" >/dev/null
[[ -f "$TMP/002-beta.done.md" ]] || { echo "FAIL: missing 002 done rename"; exit 1; }

# Fresh task for plan→…→commit happy path + fail / force cases
cat > "$TMP/003-gamma.md" <<'EOF'
# 003-gamma

## Definition of done
- Transition validation cases.
EOF
$TP init "$TMP" >/dev/null

$TP set 003-gamma --status in-progress --phase plan --dir "$TMP" >/dev/null
$TP set 003-gamma --phase fact --dir "$TMP" >/dev/null
$TP set 003-gamma --phase implement --dir "$TMP" >/dev/null
$TP set 003-gamma --phase check --dir "$TMP" >/dev/null
$TP set 003-gamma --phase commit --dir "$TMP" >/dev/null
$TP set 003-gamma --status done --dir "$TMP" >/dev/null
phase_after="$(python3 -c 'import json; print(json.load(open("'"$TMP"'/.pipeline/state.json"))["tasks"][2]["phase"])')"
[[ "$phase_after" == "done" ]] || { echo "FAIL: auto phase=done expected, got $phase_after"; exit 1; }

# Reset 003 for fail cases: re-init won't reset known status — use force to put back in-progress/plan
$TP set 003-gamma --status in-progress --phase plan --force --dir "$TMP" >/dev/null 2>/tmp/tp-force-warn.txt
grep -q 'предупреждение' /tmp/tp-force-warn.txt || { echo "FAIL: expected --force warning on stderr"; cat /tmp/tp-force-warn.txt; exit 1; }

ec=0
err="$(mktemp)"
$TP set 003-gamma --phase commit --dir "$TMP" >"$err" 2>&1 || ec=$?
[[ "$ec" -ne 0 ]] || { echo "FAIL: plan→commit should fail"; cat "$err"; exit 1; }
grep -q 'запрещён переход' "$err" || { echo "FAIL: expected transition message"; cat "$err"; exit 1; }

ec=0
$TP set 003-gamma --phase done --dir "$TMP" >"$err" 2>&1 || ec=$?
[[ "$ec" -ne 0 ]] || { echo "FAIL: in-progress+phase done should fail"; cat "$err"; exit 1; }

ec=0
$TP set 003-gamma --status todo --phase plan --dir "$TMP" >"$err" 2>&1 || ec=$?
[[ "$ec" -ne 0 ]] || { echo "FAIL: todo+phase plan should fail"; cat "$err"; exit 1; }

$TP set 003-gamma --status done --phase done --force --dir "$TMP" >/dev/null 2>/dev/null
ec=0
$TP set 003-gamma --phase commit --dir "$TMP" >"$err" 2>&1 || ec=$?
[[ "$ec" -ne 0 ]] || { echo "FAIL: done+phase commit should fail"; cat "$err"; exit 1; }

# blocked with null phase
cat > "$TMP/004-delta.md" <<'EOF'
# 004-delta
EOF
$TP init "$TMP" >/dev/null
ec=0
$TP set 004-delta --status blocked --dir "$TMP" >"$err" 2>&1 || ec=$?
[[ "$ec" -ne 0 ]] || { echo "FAIL: blocked with null phase should fail"; cat "$err"; exit 1; }

# force allows illegal phase jump
$TP set 003-gamma --status in-progress --phase plan --force --dir "$TMP" >/dev/null 2>/dev/null
force_out="$(mktemp)"
force_err="$(mktemp)"
$TP set 003-gamma --phase commit --force --dir "$TMP" >"$force_out" 2>"$force_err"
grep -q 'предупреждение' "$force_err" || { echo "FAIL: force jump missing warning"; cat "$force_err"; exit 1; }
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$force_out" || { echo "FAIL: force jump stdout not JSON"; cat "$force_out"; exit 1; }
phase_forced="$(python3 -c 'import json; t=json.load(open("'"$TMP"'/.pipeline/state.json"))["tasks"]; print([x for x in t if x["id"]=="003-gamma"][0]["phase"])')"
[[ "$phase_forced" == "commit" ]] || { echo "FAIL: force jump should set commit, got $phase_forced"; exit 1; }

# --- init: infer status from filename ---
INF="$(mktemp -d)"
trap 'rm -rf "$TMP" "$INF"' EXIT

cat > "$INF/001-a.in-work.md" <<'EOF'
# 001-a
EOF
cat > "$INF/002-b.md" <<'EOF'
# 002-b
EOF
$TP init "$INF" >/dev/null
st_a="$(python3 -c 'import json; t=json.load(open("'"$INF"'/.pipeline/state.json"))["tasks"]; print([x for x in t if x["id"]=="001-a"][0]["status"])')"
st_b="$(python3 -c 'import json; t=json.load(open("'"$INF"'/.pipeline/state.json"))["tasks"]; print([x for x in t if x["id"]=="002-b"][0]["status"])')"
[[ "$st_a" == "in-progress" ]] || { echo "FAIL: 001-a should be in-progress from .in-work, got $st_a"; exit 1; }
[[ "$st_b" == "todo" ]] || { echo "FAIL: 002-b should be todo, got $st_b"; exit 1; }

# known id: phase survives re-init
$TP set 001-a --phase fact --dir "$INF" >/dev/null
$TP init "$INF" >/dev/null
ph_a="$(python3 -c 'import json; t=json.load(open("'"$INF"'/.pipeline/state.json"))["tasks"]; print([x for x in t if x["id"]=="001-a"][0]["phase"])')"
[[ "$ph_a" == "fact" ]] || { echo "FAIL: known phase should stay fact after re-init, got $ph_a"; exit 1; }

# two .in-work without state → one in-progress, one blocked
INF2="$(mktemp -d)"
trap 'rm -rf "$TMP" "$INF" "$INF2"' EXIT
cat > "$INF2/001-x.in-work.md" <<'EOF'
# 001-x
EOF
cat > "$INF2/002-y.in-work.md" <<'EOF'
# 002-y
EOF
init_out="$(mktemp)"
init_stderr="$(mktemp)"
$TP init "$INF2" >"$init_out" 2>"$init_stderr"
grep -q 'несколько in-progress' "$init_stderr" || { echo "FAIL: expected multi in-progress warning"; cat "$init_stderr"; exit 1; }
python3 - <<PY
import json
tasks = {t["id"]: t for t in json.load(open("$INF2/.pipeline/state.json"))["tasks"]}
assert tasks["001-x"]["status"] == "in-progress", tasks["001-x"]
assert tasks["002-y"]["status"] == "blocked", tasks["002-y"]
PY

echo "tp-state.test.sh OK"
