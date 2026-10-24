#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.volta/bin:$PATH"

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

echo "All tests passed."
