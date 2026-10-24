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
grep -qiE 'предупреждение|warning|попередження' /tmp/tp-force-warn.txt || { echo "FAIL: expected --force warning on stderr"; cat /tmp/tp-force-warn.txt; exit 1; }

ec=0
err="$(mktemp)"
$TP set 003-gamma --phase commit --dir "$TMP" >"$err" 2>&1 || ec=$?
[[ "$ec" -ne 0 ]] || { echo "FAIL: plan→commit should fail"; cat "$err"; exit 1; }
grep -qiE 'запрещён переход|illegal phase transition|заборонений перехід' "$err" || { echo "FAIL: expected transition message"; cat "$err"; exit 1; }

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
grep -qiE 'предупреждение|warning|попередження' "$force_err" || { echo "FAIL: force jump missing warning"; cat "$force_err"; exit 1; }
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
grep -qiE 'несколько in-progress|multiple in-progress|кілька in-progress' "$init_stderr" || { echo "FAIL: expected multi in-progress warning"; cat "$init_stderr"; exit 1; }

# lang: new init → en; re-init migrates missing lang → ru
LANG_TMP="$(mktemp -d)"
cat > "$LANG_TMP/001-z.md" <<'EOF'
# z
EOF
$TP init "$LANG_TMP" >/dev/null
lang_new="$(python3 -c 'import json; print(json.load(open("'"$LANG_TMP"'/.pipeline/state.json"))["config"]["lang"])')"
[[ "$lang_new" == "en" ]] || { echo "FAIL: new init lang should be en, got $lang_new"; exit 1; }
python3 - <<PY
import json
from pathlib import Path
p = Path("$LANG_TMP") / ".pipeline" / "state.json"
state = json.loads(p.read_text())
del state["config"]["lang"]
p.write_text(json.dumps(state, indent=2) + "\n")
PY
$TP init "$LANG_TMP" >/dev/null
lang_old="$(python3 -c 'import json; print(json.load(open("'"$LANG_TMP"'/.pipeline/state.json"))["config"]["lang"])')"
[[ "$lang_old" == "ru" ]] || { echo "FAIL: migrate missing lang → ru, got $lang_old"; exit 1; }
python3 - <<PY
import json
tasks = {t["id"]: t for t in json.load(open("$INF2/.pipeline/state.json"))["tasks"]}
assert tasks["001-x"]["status"] == "in-progress", tasks["001-x"]
assert tasks["002-y"]["status"] == "blocked", tasks["002-y"]
PY

# --- doctor: mismatch detection + --fix ---
DOC="$(mktemp -d)"
trap 'rm -rf "$TMP" "$INF" "$INF2" "$DOC" "$LANG_TMP"' EXIT
cat > "$DOC/001-ok.md" <<'EOF'
# ok
EOF
cat > "$DOC/002-mis.md" <<'EOF'
# mis
EOF
$TP init "$DOC" >/dev/null
# Corrupt state: status done but file still plain .md
python3 - <<PY
import json
from pathlib import Path
p = Path("$DOC") / ".pipeline" / "state.json"
state = json.loads(p.read_text())
for task in state["tasks"]:
    if task["id"] == "002-mis":
        task["status"] = "done"
        task["phase"] = "done"
        # leave task["file"] as 002-mis.md → mismatch
p.write_text(json.dumps(state, indent=2) + "\n")
PY
doc_out="$(mktemp)"
ec=0
$TP doctor --dir "$DOC" >"$doc_out" 2>/dev/null || ec=$?
[[ "$ec" -eq 1 ]] || { echo "FAIL: doctor should exit 1 on problems"; cat "$doc_out"; exit 1; }
python3 - <<PY
import json
r = json.load(open("$doc_out"))
kinds = [p["kind"] for p in r["problems"]]
assert "fileStatusMismatch" in kinds, r
assert r.get("lang"), r
PY
ec=0
$TP doctor --fix --dir "$DOC" >"$doc_out" 2>/dev/null || ec=$?
[[ "$ec" -eq 0 ]] || { echo "FAIL: doctor --fix should exit 0 when cleaned"; cat "$doc_out"; exit 1; }
[[ -f "$DOC/002-mis.done.md" ]] || { echo "FAIL: doctor --fix should rename to .done.md"; exit 1; }
python3 - <<PY
import json
r = json.load(open("$doc_out"))
assert r["problems"] == [], r
assert any(f.get("kind") == "fileStatusMismatch" for f in r["fixed"]), r
PY

# multiple in-progress → doctor --fix
DOC2="$(mktemp -d)"
trap 'rm -rf "$TMP" "$INF" "$INF2" "$DOC" "$DOC2" "$LANG_TMP"' EXIT
cat > "$DOC2/a.in-work.md" <<'EOF'
# a
EOF
cat > "$DOC2/b.in-work.md" <<'EOF'
# b
EOF
mkdir -p "$DOC2/.pipeline"
python3 - <<PY
import json
from pathlib import Path
root = Path("$DOC2")
state = {
  "version": 1,
  "config": {"gateAfterFact": False, "maxCheckRounds": 2, "push": True, "reviewModel": None, "continueNextTask": True, "lang": "en"},
  "tasks": [
    {"id": "a", "file": "a.in-work.md", "status": "in-progress", "phase": "plan"},
    {"id": "b", "file": "b.in-work.md", "status": "in-progress", "phase": "plan"},
  ],
}
(root / ".pipeline" / "state.json").write_text(json.dumps(state, indent=2) + "\n")
PY
ec=0
$TP doctor --dir "$DOC2" >"$doc_out" 2>/dev/null || ec=$?
[[ "$ec" -eq 1 ]] || { echo "FAIL: doctor should flag multipleInProgress"; cat "$doc_out"; exit 1; }
ec=0
$TP doctor --fix --dir "$DOC2" >"$doc_out" 2>/dev/null || ec=$?
[[ "$ec" -eq 0 ]] || { echo "FAIL: doctor --fix multi should exit 0"; cat "$doc_out"; exit 1; }
python3 - <<PY
import json
tasks = {t["id"]: t for t in json.load(open("$DOC2/.pipeline/state.json"))["tasks"]}
assert tasks["a"]["status"] == "in-progress", tasks
assert tasks["b"]["status"] == "blocked", tasks
r = json.load(open("$doc_out"))
assert r["problems"] == [], r
PY

# .done file + status todo → promote status on --fix
DOC3="$(mktemp -d)"
trap 'rm -rf "$TMP" "$INF" "$INF2" "$DOC" "$DOC2" "$DOC3" "$LANG_TMP"' EXIT
cat > "$DOC3/c.done.md" <<'EOF'
# c
EOF
mkdir -p "$DOC3/.pipeline"
python3 - <<PY
import json
from pathlib import Path
root = Path("$DOC3")
state = {
  "version": 1,
  "config": {"lang": "en", "gateAfterFact": False, "maxCheckRounds": 2, "push": True, "reviewModel": None, "continueNextTask": True},
  "tasks": [
    {"id": "c", "file": "c.done.md", "status": "todo", "phase": None},
  ],
}
(root / ".pipeline" / "state.json").write_text(json.dumps(state, indent=2) + "\n")
PY
$TP doctor --fix --dir "$DOC3" >"$doc_out" 2>/dev/null
[[ -f "$DOC3/c.done.md" ]] || { echo "FAIL: should keep .done.md"; exit 1; }
python3 - <<PY
import json
t = json.load(open("$DOC3/.pipeline/state.json"))["tasks"][0]
assert t["status"] == "done" and t["phase"] == "done", t
assert t["file"] == "c.done.md", t
PY

echo "tp-state.test.sh OK"
