#!/usr/bin/env bash
# install.sh --lang + install.json persistence (isolated CURSOR_DIR).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.volta/bin:$PATH"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export CURSOR_DIR="$TMP/cursor"
mkdir -p "$CURSOR_DIR"

assert_link_contains() {
  local link="$1"
  local needle="$2"
  local target
  target="$(readlink "$link")"
  [[ "$target" == *"$needle"* ]] || {
    echo "FAIL: $link -> $target (expected substring $needle)" >&2
    exit 1
  }
}

echo "--- install --lang uk ---"
"$REPO_ROOT/install.sh" --lang uk >/dev/null
assert_link_contains "$CURSOR_DIR/commands/task-pipeline.md" "/commands/uk/"
assert_link_contains "$CURSOR_DIR/commands/tp-fact.md" "/commands/uk/"
assert_link_contains "$CURSOR_DIR/rules/task-pipeline-no-stop.mdc" "/rules/uk/"
[[ -f "$CURSOR_DIR/task-pipeline/install.json" ]] || { echo "FAIL: missing install.json"; exit 1; }
lang="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).lang)" "$CURSOR_DIR/task-pipeline/install.json")"
[[ "$lang" == "uk" ]] || { echo "FAIL: install.json lang=$lang want uk"; exit 1; }

echo "--- reinstall without flag keeps uk ---"
"$REPO_ROOT/install.sh" >/dev/null
assert_link_contains "$CURSOR_DIR/commands/task-pipeline.md" "/commands/uk/"
lang="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).lang)" "$CURSOR_DIR/task-pipeline/install.json")"
[[ "$lang" == "uk" ]] || { echo "FAIL: persisted lang lost ($lang)"; exit 1; }

echo "--- --lang en switches packs ---"
"$REPO_ROOT/install.sh" --lang en >/dev/null
assert_link_contains "$CURSOR_DIR/commands/task-pipeline.md" "/commands/en/"
assert_link_contains "$CURSOR_DIR/rules/task-pipeline-no-stop.mdc" "/rules/en/"
lang="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).lang)" "$CURSOR_DIR/task-pipeline/install.json")"
[[ "$lang" == "en" ]] || { echo "FAIL: install.json lang=$lang want en"; exit 1; }

echo "--- TP_LANG overrides install.json when no --lang ---"
# persist en, then TP_LANG=ru without --lang
TP_LANG=ru "$REPO_ROOT/install.sh" >/dev/null
assert_link_contains "$CURSOR_DIR/commands/task-pipeline.md" "/commands/ru/"
lang="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).lang)" "$CURSOR_DIR/task-pipeline/install.json")"
[[ "$lang" == "ru" ]] || { echo "FAIL: TP_LANG did not persist ($lang)"; exit 1; }

echo "--- default en on fresh CURSOR_DIR ---"
rm -rf "$CURSOR_DIR"
mkdir -p "$CURSOR_DIR"
"$REPO_ROOT/install.sh" >/dev/null
assert_link_contains "$CURSOR_DIR/commands/task-pipeline.md" "/commands/en/"
lang="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).lang)" "$CURSOR_DIR/task-pipeline/install.json")"
[[ "$lang" == "en" ]] || { echo "FAIL: default lang=$lang want en"; exit 1; }

echo "--- uninstall leaves install.json ---"
"$REPO_ROOT/install.sh" --uninstall >/dev/null
[[ -f "$CURSOR_DIR/task-pipeline/install.json" ]] || { echo "FAIL: install.json removed on uninstall"; exit 1; }
[[ ! -e "$CURSOR_DIR/commands/task-pipeline.md" ]] || { echo "FAIL: command symlink still present"; exit 1; }

echo "install-lang: ok"
