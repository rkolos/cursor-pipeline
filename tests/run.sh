#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.volta/bin:$PATH"

# Isolate ~/.cursor/task-pipeline (active.json, sessions) from the developer machine.
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
trap 'rm -rf "$TEST_HOME"' EXIT

echo "=== syntax check ==="
for f in "$REPO_ROOT/scripts"/*.mjs; do
  node --check "$f"
done

echo "=== hook-question ==="
"$REPO_ROOT/tests/hook-question.test.sh"

echo "=== tp-state ==="
"$REPO_ROOT/tests/tp-state.test.sh"

echo "=== merge-hooks ==="
"$REPO_ROOT/tests/merge-hooks.test.sh"

echo "=== hook-followup ==="
"$REPO_ROOT/tests/hook-followup.test.sh"

echo "=== install-lang ==="
"$REPO_ROOT/tests/install-lang.test.sh"

echo "All tests passed."
