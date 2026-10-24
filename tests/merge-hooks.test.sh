#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="node $REPO_ROOT/scripts/merge-hooks.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "merge-hooks.test.sh"

TARGET="$TMP/hooks.json"
FRAGMENT="$TMP/fragment.json"

cat > "$TARGET" <<'EOF'
{
  "version": 1,
  "hooks": {
    "stop": [
      {
        "command": "./other/tool.sh",
        "timeout": 3
      },
      {
        "command": "./task-pipeline/hook.sh stop",
        "timeout": 5,
        "loop_limit": 10
      }
    ]
  }
}
EOF

cat > "$FRAGMENT" <<'EOF'
{
  "version": 1,
  "hooks": {
    "stop": [
      {
        "command": "./task-pipeline/hook.sh stop",
        "timeout": 15,
        "loop_limit": 100
      }
    ]
  }
}
EOF

$MERGE --target "$TARGET" --fragment "$FRAGMENT"

python3 - <<PY
import json
data = json.load(open("$TARGET"))
stop = data["hooks"]["stop"]
assert len(stop) == 2, stop
assert stop[0]["command"] == "./other/tool.sh" and stop[0]["timeout"] == 3, stop[0]
assert "task-pipeline/hook.sh" in stop[1]["command"]
assert stop[1]["timeout"] == 15 and stop[1]["loop_limit"] == 100, stop[1]
PY

# idempotent re-merge
before="$(cat "$TARGET")"
$MERGE --target "$TARGET" --fragment "$FRAGMENT"
after="$(cat "$TARGET")"
[[ "$before" == "$after" ]] || { echo "FAIL: re-merge changed JSON"; diff -u <(echo "$before") <(echo "$after") || true; exit 1; }

# uninstall removes only pipeline
$MERGE --target "$TARGET" --uninstall
python3 - <<PY
import json
data = json.load(open("$TARGET"))
stop = data["hooks"]["stop"]
assert len(stop) == 1 and stop[0]["command"] == "./other/tool.sh", stop
assert not any("task-pipeline/hook.sh" in str(e.get("command","")) for e in stop)
PY

echo "merge-hooks.test.sh OK"
