#!/usr/bin/env bash
# Install cursor-pipeline into ~/.cursor via symlinks + hooks merge.
#   ./install.sh           install or refresh
#   ./install.sh --uninstall   remove symlinks and pipeline hook entries
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CURSOR_DIR="${CURSOR_DIR:-$HOME/.cursor}"
COMMANDS_DIR="$CURSOR_DIR/commands"
RULES_DIR="$CURSOR_DIR/rules"
TP_DIR="$CURSOR_DIR/task-pipeline"
HOOKS_FILE="$CURSOR_DIR/hooks.json"
MERGE="$REPO_ROOT/scripts/merge-hooks.mjs"
BACKUP_ROOT="$CURSOR_DIR/task-pipeline-backup"

UNINSTALL=false
if [[ "${1:-}" == "--uninstall" ]]; then
  UNINSTALL=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--uninstall]" >&2
  exit 1
fi

die() {
  echo "install.sh: $*" >&2
  exit 1
}

require_node() {
  export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.volta/bin:$PATH"
  if ! command -v node >/dev/null 2>&1 && [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
  fi
  command -v node >/dev/null || die "Node.js is required. Install Node 18+ and retry."
}

warn_optional() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq not found — only needed for scripts/run-loop.sh (batch mode)."
  fi
  if ! command -v cursor-agent >/dev/null 2>&1 && ! command -v agent >/dev/null 2>&1; then
    echo "Warning: Cursor CLI (cursor-agent) not found — only needed for scripts/run-loop.sh."
  fi
}

resolve_link() {
  if [[ -L "$1" ]]; then
    readlink "$1"
  else
    echo ""
  fi
}

points_into_repo() {
  local target="$1"
  local link
  link="$(resolve_link "$target")"
  [[ -n "$link" ]] && [[ "$link" == "$REPO_ROOT"* ]]
}

backup_file() {
  local rel="$1"
  local src="$2"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local dest="$BACKUP_ROOT-$ts/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  echo "  backed up $rel -> $dest"
}

install_symlink() {
  local src="$1"
  local dest="$2"
  local rel="${dest#$CURSOR_DIR/}"

  mkdir -p "$(dirname "$dest")"

  if points_into_repo "$dest"; then
    if [[ "$(resolve_link "$dest")" == "$src" ]]; then
      echo "  ok (already linked): $rel"
      return 0
    fi
  fi

  if [[ -e "$dest" ]] && ! points_into_repo "$dest"; then
    backup_file "$rel" "$dest"
    rm -rf "$dest"
  elif [[ -L "$dest" ]] && ! points_into_repo "$dest"; then
    backup_file "$rel" "$dest"
    rm -f "$dest"
  fi

  ln -sfn "$src" "$dest"
  echo "  linked: $rel"
}

remove_symlink_if_repo() {
  local dest="$1"
  local rel="${dest#$CURSOR_DIR/}"
  if points_into_repo "$dest"; then
    rm -f "$dest"
    echo "  removed link: $rel"
  fi
}

if $UNINSTALL; then
  echo "Uninstalling cursor-pipeline from $CURSOR_DIR ..."
  require_node
  remove_symlink_if_repo "$COMMANDS_DIR/task-pipeline.md"
  remove_symlink_if_repo "$COMMANDS_DIR/tp-fact.md"
  remove_symlink_if_repo "$COMMANDS_DIR/tp-check.md"
  for f in "$RULES_DIR"/task-pipeline-*.mdc; do
    [[ -e "$f" ]] || continue
    remove_symlink_if_repo "$f"
  done
  for name in hook.mjs hook.sh tp-state.mjs run-loop.sh; do
    remove_symlink_if_repo "$TP_DIR/$name"
  done
  node "$MERGE" --target "$HOOKS_FILE" --uninstall
  echo "Done. Pipeline state in $TP_DIR (active.json, sessions/) was left intact."
  echo "Reload the Cursor window (Developer: Reload Window)."
  exit 0
fi

echo "Installing cursor-pipeline from $REPO_ROOT ..."
require_node
warn_optional

mkdir -p "$COMMANDS_DIR" "$RULES_DIR" "$TP_DIR"

# Locale for agent prompts (09 adds --lang; until then install keeps RU baseline).
INSTALL_LANG="${INSTALL_LANG:-ru}"
COMMANDS_SRC="$REPO_ROOT/commands/$INSTALL_LANG"
RULES_SRC="$REPO_ROOT/rules/$INSTALL_LANG"
[[ -d "$COMMANDS_SRC" ]] || die "missing commands/$INSTALL_LANG"
[[ -d "$RULES_SRC" ]] || die "missing rules/$INSTALL_LANG"

echo "Commands ($INSTALL_LANG):"
install_symlink "$COMMANDS_SRC/task-pipeline.md" "$COMMANDS_DIR/task-pipeline.md"
install_symlink "$COMMANDS_SRC/tp-fact.md" "$COMMANDS_DIR/tp-fact.md"
install_symlink "$COMMANDS_SRC/tp-check.md" "$COMMANDS_DIR/tp-check.md"

echo "Rules ($INSTALL_LANG):"
# All task-pipeline-*.mdc (no-stop, autonomous-checks, recommended-answers, commit-before-done, …)
for src in "$RULES_SRC"/task-pipeline-*.mdc; do
  [[ -f "$src" ]] || continue
  install_symlink "$src" "$RULES_DIR/$(basename "$src")"
done

echo "Scripts -> $TP_DIR:"
install_symlink "$REPO_ROOT/scripts/hook.mjs" "$TP_DIR/hook.mjs"
install_symlink "$REPO_ROOT/scripts/hook.sh" "$TP_DIR/hook.sh"
install_symlink "$REPO_ROOT/scripts/tp-state.mjs" "$TP_DIR/tp-state.mjs"
install_symlink "$REPO_ROOT/scripts/run-loop.sh" "$TP_DIR/run-loop.sh"

echo "Hooks:"
node "$MERGE" --target "$HOOKS_FILE" --fragment "$REPO_ROOT/hooks/hooks.json"

echo ""
echo "Install complete."
echo "Reload the Cursor window (Developer: Reload Window) so commands and rules reload."
echo "Then run: /task-pipeline <path-to-tasks-folder>"
