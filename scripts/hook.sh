#!/bin/bash
# Wrapper for hook.mjs: Cursor GUI may not have node on PATH.
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.volta/bin:$PATH"
if ! command -v node >/dev/null 2>&1 && [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
fi
if ! command -v node >/dev/null 2>&1; then
  [ "$1" = "prompt" ] && echo '{"continue":true}' || echo '{}'
  exit 0
fi
exec node "$(dirname "$0")/hook.mjs" "$@"
