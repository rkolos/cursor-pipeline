#!/usr/bin/env bash
# tp-state hook-followup branches (HOME should be a temp dir from run.sh).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="node $REPO_ROOT/scripts/tp-state.mjs"

has_key() {
  python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if sys.argv[1] in d else 1)' "$1"
}

echo "hook-followup.test.sh"

# --- in-progress / implement → followup, no kind ---
A="$(mktemp -d)"
cat > "$A/001-a.md" <<'EOF'
# a
EOF
$TP init "$A" >/dev/null
$TP set 001-a --status in-progress --phase implement --dir "$A" >/dev/null
out="$($TP hook-followup --workspace "$A")"
echo "$out" | has_key followup || { echo "FAIL: expected followup for implement"; echo "$out"; exit 1; }
echo "$out" | has_key kind && { echo "FAIL: implement followup must not have kind"; echo "$out"; exit 1; }
kind="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("kind",""))')"
[[ -z "$kind" ]] || { echo "FAIL: kind should be empty, got $kind"; exit 1; }

# --- awaiting-approval → notice, no followup ---
$TP set 001-a --phase awaiting-approval --force --dir "$A" >/dev/null 2>/dev/null
out="$($TP hook-followup --workspace "$A")"
echo "$out" | has_key notice || { echo "FAIL: expected notice for awaiting-approval"; echo "$out"; exit 1; }
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "followup" not in d or not d.get("followup")'

# --- blocked without answers → notice ---
B="$(mktemp -d)"
cat > "$B/001-b.md" <<'EOF'
# b
EOF
cat > "$B/002-c.md" <<'EOF'
# c
EOF
$TP init "$B" >/dev/null
mkdir -p "$B/.pipeline/runs/001-b"
cat > "$B/.pipeline/runs/001-b/questions.md" <<'EOF'
## Q1
Варианты: A / B
Ответ:

EOF
$TP set 001-b --status blocked --phase implement --dir "$B" >/dev/null
out="$($TP hook-followup --workspace "$B")"
echo "$out" | has_key notice || { echo "FAIL: expected notice for blocked"; echo "$out"; exit 1; }
echo "$out" | grep -q 'questions.md' || { echo "FAIL: notice should mention questions.md"; echo "$out"; exit 1; }
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert not d.get("followup")'

# --- blocked + Рекомендация → followup resume ---
mkdir -p "$B/.pipeline/runs/001-b"
cat > "$B/.pipeline/runs/001-b/questions.md" <<'EOF'
## Q1
Варианты: A / B
Рекомендация: A
Ответ:

EOF
out="$($TP hook-followup --workspace "$B")"
echo "$out" | has_key followup || { echo "FAIL: expected followup after recommendation"; echo "$out"; exit 1; }
echo "$out" | grep -q 'in-progress' || { echo "FAIL: followup should mention in-progress"; echo "$out"; exit 1; }

# --- blocked + Recommendation/Answer (EN) → followup ---
E="$(mktemp -d)"
cat > "$E/001-e.md" <<'EOF'
# e
EOF
$TP init "$E" >/dev/null
mkdir -p "$E/.pipeline/runs/001-e"
cat > "$E/.pipeline/runs/001-e/questions.md" <<'EOF'
## Q1
Options: A / B
Recommendation: B
Answer:

EOF
$TP set 001-e --status blocked --phase implement --dir "$E" >/dev/null
out="$($TP hook-followup --workspace "$E")"
echo "$out" | has_key followup || { echo "FAIL: EN Recommendation should unblock"; echo "$out"; exit 1; }
grep -q '^Answer: B' "$E/.pipeline/runs/001-e/questions.md" || { echo "FAIL: auto-fill should write Answer: B"; cat "$E/.pipeline/runs/001-e/questions.md"; exit 1; }

# --- next-task when continueNextTask true ---
C="$(mktemp -d)"
cat > "$C/001-x.md" <<'EOF'
# x
EOF
cat > "$C/002-y.md" <<'EOF'
# y
EOF
$TP init "$C" >/dev/null
$TP set 001-x --status in-progress --phase plan --dir "$C" >/dev/null
$TP set 001-x --status done --phase done --dir "$C" >/dev/null
out="$($TP hook-followup --workspace "$C")"
kind="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("kind",""))')"
[[ "$kind" == "next-task" ]] || { echo "FAIL: expected kind next-task, got $kind"; echo "$out"; exit 1; }
echo "$out" | has_key followup || { echo "FAIL: next-task needs followup"; exit 1; }

# --- continueNextTask false → notice, no next-task followup ---
python3 - <<PY
import json
from pathlib import Path
p = Path("$C") / ".pipeline" / "state.json"
state = json.loads(p.read_text())
state["config"]["continueNextTask"] = False
p.write_text(json.dumps(state, indent=2) + "\n")
PY
out="$($TP hook-followup --workspace "$C")"
kind="$(echo "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("kind",""))')"
[[ -z "$kind" ]] || { echo "FAIL: continueNextTask=false must not set kind next-task, got $kind"; echo "$out"; exit 1; }
echo "$out" | has_key notice || { echo "FAIL: expected notice when continueNextTask=false"; echo "$out"; exit 1; }
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert not d.get("followup"), d'

# --- lang=en next-task followup is English ---
EN="$(mktemp -d)"
cat > "$EN/001-p.md" <<'EOF'
# p
EOF
cat > "$EN/002-q.md" <<'EOF'
# q
EOF
$TP init "$EN" >/dev/null
python3 - <<PY
import json
from pathlib import Path
p = Path("$EN") / ".pipeline" / "state.json"
state = json.loads(p.read_text())
assert state["config"].get("lang") == "en", state["config"]
p.write_text(json.dumps(state, indent=2) + "\n")
PY
$TP set 001-p --status in-progress --phase plan --dir "$EN" >/dev/null
$TP set 001-p --status done --phase done --dir "$EN" >/dev/null
out="$($TP hook-followup --workspace "$EN")"
echo "$out" | grep -q 'Continue the task pipeline' || { echo "FAIL: en followup should be English"; echo "$out"; exit 1; }
echo "$out" | grep -qiE 'Продолжай|Продовжуй' && { echo "FAIL: en followup must not be RU/UK"; echo "$out"; exit 1; }

# --- lang=uk next-task followup is Ukrainian ---
UK="$(mktemp -d)"
cat > "$UK/001-u.md" <<'EOF'
# u
EOF
cat > "$UK/002-v.md" <<'EOF'
# v
EOF
$TP init "$UK" >/dev/null
python3 - <<PY
import json
from pathlib import Path
p = Path("$UK") / ".pipeline" / "state.json"
state = json.loads(p.read_text())
state["config"]["lang"] = "uk"
p.write_text(json.dumps(state, indent=2) + "\n")
PY
$TP set 001-u --status in-progress --phase plan --dir "$UK" >/dev/null
$TP set 001-u --status done --phase done --dir "$UK" >/dev/null
out="$($TP hook-followup --workspace "$UK")"
echo "$out" | grep -q 'Продовжуй конвеєр' || { echo "FAIL: uk followup should be Ukrainian"; echo "$out"; exit 1; }
echo "$out" | grep -q 'Continue the task pipeline' && { echo "FAIL: uk followup must not be English"; echo "$out"; exit 1; }

echo "hook-followup.test.sh OK"
