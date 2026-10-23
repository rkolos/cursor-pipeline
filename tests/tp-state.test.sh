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

echo "tp-state.test.sh OK"
