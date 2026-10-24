#!/bin/bash
# Batch /task-pipeline via Cursor CLI: one agent session per invocation until done, blocked, or stalled.
# After each done task: docker container/image/builder prune (testcontainers junk).
# With TP_AUTONOMOUS=1 the agent uses focused checks on commit, not full precommit (see task-pipeline §2a).
#
#   ~/.cursor/task-pipeline/run-loop.sh <tasks-dir> [--max-tasks N] [--max-runs-per-task M] [--model MODEL]
#
# Exit codes: 0 success or --max-tasks; 2 blocked; 3 no progress; 1 environment error.
set -uo pipefail

TP="node $HOME/.cursor/task-pipeline/tp-state.mjs"
MAX_TASKS=1000
MAX_RUNS=12
MODEL=""

if [ $# -lt 1 ]; then
  sed -n '2,9p' "$0"
  exit 1
fi
TASKS_DIR="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --max-tasks) MAX_TASKS="$2"; shift 2 ;;
    --max-runs-per-task) MAX_RUNS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "неизвестный аргумент: $1"; exit 1 ;;
  esac
done

AGENT_BIN="$(command -v cursor-agent || command -v agent || true)"
if [ -z "$AGENT_BIN" ]; then
  echo "Cursor CLI не найден. Установка: curl https://cursor.com/install -fsS | bash"
  exit 1
fi
command -v jq >/dev/null || { echo "нужен jq"; exit 1; }

TASKS_DIR="$(cd "$TASKS_DIR" && pwd -P)" || exit 1
WORKSPACE="$(git -C "$TASKS_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$TASKS_DIR")"
cd "$WORKSPACE" || exit 1
$TP init "$TASKS_DIR" >/dev/null || exit 1
LOG_DIR="$TASKS_DIR/.pipeline/logs"
mkdir -p "$LOG_DIR"

STATE_JSON="$TASKS_DIR/.pipeline/state.json"
STATUS_WATCH_PID=""
# Resolve i18n next to the real tp-state.mjs (install uses symlinks into ~/.cursor/task-pipeline).
TP_SCRIPTS_DIR="$(node -e "const fs=require('fs');const p=require('path');const t=process.argv[1];console.log(p.dirname(fs.realpathSync(t)));" "$HOME/.cursor/task-pipeline/tp-state.mjs")"

state_of() { $TP show "$1" --dir "$TASKS_DIR" | jq -r '"\(.status)\(if .phase and .phase != .status then "/\(.phase)" else "" end)"'; }

# Notify strings from scripts/locales/<config.lang>.json (vars as name=value args).
tp_t() {
  local key="$1"
  shift
  node --input-type=module -e "
    import { readFileSync } from 'node:fs';
    import { pathToFileURL } from 'node:url';
    import { join } from 'node:path';
    const scriptsDir = process.argv[1];
    const statePath = process.argv[2];
    const key = process.argv[3];
    const { t, resolveLang } = await import(pathToFileURL(join(scriptsDir, 'i18n.mjs')).href);
    let config = {};
    try { config = JSON.parse(readFileSync(statePath, 'utf8')).config || {}; } catch {}
    const lang = resolveLang(config);
    const vars = {};
    for (const pair of process.argv.slice(4)) {
      const i = pair.indexOf('=');
      if (i > 0) vars[pair.slice(0, i)] = pair.slice(i + 1);
    }
    process.stdout.write(t(lang, key, vars));
  " "$TP_SCRIPTS_DIR" "$STATE_JSON" "$key" "$@"
}

# stream-json агента → читаемые строки: реплики, вызовы инструментов, итог. Не-JSON строки (ошибки сети) — как есть.
humanize_stream() {
  jq --unbuffered -R -r '
    . as $raw
    | (try fromjson catch null) as $e
    | if ($e | type) != "object" then (if $raw == "" then empty else $raw end)
      elif $e.type == "assistant" then
        ($e.message.content // [] | map(select(.type == "text") | .text) | join("")) as $txt
        | if $txt == "" then empty else "» \($txt)" end
      elif $e.type == "tool_call" and $e.subtype == "started" then
        ($e.tool_call // {} | to_entries | map(select(.key | endswith("ToolCall"))) | .[0]) as $t
        | if $t == null then empty else
            ($t.value.args // {}) as $a
            | "⚙ \($t.key | sub("ToolCall$"; "")): \(($a.command // $a.path // $a.pattern // $a.globPattern // $a.query // $a.toolName // $a.name // ($a | tostring)) | tostring | gsub("\n"; " ") | .[0:160])"
          end
      elif $e.type == "result" then
        "■ агент завершил: \($e.subtype // "?")\(if $e.is_error then " (ошибка)" else "" end), \((($e.duration_ms // 0) / 1000) | floor)с"
      else empty end'
}

print_board() {
  [ -f "$STATE_JSON" ] || return 0
  jq -r --arg now "$(date '+%H:%M:%S')" '
    def phase: (.phase // "—");
    (.tasks) as $t
    | ($t | map(.status) | group_by(.) | map({key: .[0], value: length}) | from_entries) as $c
    | ($t | map(select(.status == "in-progress"))[0]) as $cur
    | ($t | map(select(.status == "done")) | .[-2:] | map(.id) | join(", ")) as $recent
    | ($t | map(select(.status == "todo"))[:3] | map(.id) | join(", ")) as $next
    | ($t | map(select(.status == "blocked")) | map(.id) | join(", ")) as $blocked
    | [
        "  ┌─ конвейер \($now)",
        "  │ \($c.done // 0) done  ·  \($c["in-progress"] // 0) in-progress  ·  \($c.blocked // 0) blocked  ·  \($c.todo // 0) todo  ·  \($t | length) всего",
        (if $cur then "  │ сейчас: \($cur.id)  [\($cur.status) / \($cur | phase)]" else "  │ сейчас: —" end),
        (if $recent != "" then "  │ недавно: \($recent)" else empty end),
        (if $next != "" then "  │ дальше:  \($next)" else empty end),
        (if $blocked != "" then "  │ blocked: \($blocked)" else empty end),
        "  └─"
      ] | join("\n")
  ' "$STATE_JSON"
}

stop_status_watch() {
  if [ -n "${STATUS_WATCH_PID:-}" ]; then
    kill "$STATUS_WATCH_PID" 2>/dev/null || true
    wait "$STATUS_WATCH_PID" 2>/dev/null || true
    STATUS_WATCH_PID=""
  fi
}

# Живой статус фазы/доски, пока агент пишет в лог. Убивается stop_status_watch.
start_status_watch() {
  local watch_id="$1"
  local log_file="$2"
  stop_status_watch
  (
    last=""
    last_beat=0
    t0=$(date +%s)
    while true; do
      cur="$(state_of "$watch_id" 2>/dev/null || echo "? ?")"
      now=$(date +%s)
      elapsed=$((now - t0))
      mm=$((elapsed / 60))
      ss=$((elapsed % 60))
      stamp="$(date '+%H:%M:%S')"
      if [ "$cur" != "$last" ]; then
        if [ -n "$last" ]; then
          echo "  ◆ $stamp $watch_id: $last → $cur  (${mm}м ${ss}с)"
        else
          echo "  ◆ $stamp $watch_id: $cur  (${mm}м ${ss}с)"
        fi
        last="$cur"
      elif [ $((elapsed - last_beat)) -ge 15 ]; then
        tail_line="$(tail -n 5 "$log_file" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -n 1 | tr -d '\r' | cut -c1-140)"
        if [ -n "$tail_line" ]; then
          echo "  … $stamp всё ещё $cur, ${mm}м ${ss}с  |  $tail_line"
        else
          echo "  … $stamp всё ещё $cur, ${mm}м ${ss}с  |  агент молчит (ждём вывод)"
        fi
        last_beat=$elapsed
      fi
      sleep 2
    done
  ) &
  STATUS_WATCH_PID=$!
}

notify() {
  echo "$1"
  if [ "$(uname)" = "Darwin" ]; then
    osascript -e "display notification \"${1//\"/\\\"}\" with title \"task-pipeline\" sound name \"Glass\"" >/dev/null 2>&1 || true
  fi
}

trap 'stop_status_watch; exit 130' INT TERM
trap 'stop_status_watch' EXIT
# Безопасная очистка мусорных тестовых контейнеров после каждой закрытой задачи.
# Только prune остановленных/dangling; работающий Up-стек (compose) не трогаем.
docker_cleanup_after_task() {
  local task_id="$1"
  if ! command -v docker >/dev/null 2>&1; then
    echo "  Docker cleanup пропущен ($task_id): docker недоступен"
    return 0
  fi
  echo "  Docker cleanup после ${task_id}…"
  docker container prune -f 2>/dev/null || true
  docker image prune -f 2>/dev/null || true
  docker builder prune -f 2>/dev/null || true
}

# Installed command file is already localized via install.sh --lang; prompt stays EN for the CLI agent.
PROMPT="TP_AUTONOMOUS=1
/task-pipeline $TASKS_DIR
Read ~/.cursor/commands/task-pipeline.md and follow it for this tasks folder. Complete as many phases of the current task as you can; change state only via tp-state.mjs. Do not ask questions in chat. In questions.md, if there is Recommendation:/Рекомендация:/Рекомендація: — copy it into Answer:/Ответ:/Відповідь: immediately and do NOT set blocked; blocked only when there is no recommendation.
Batch run: on commit do NOT run full precommit (no npm run precommit-check, no full npm test/lint/build). Only focused jest on changed paths + npm run typecheck — see § 2a in task-pipeline.md. Use the project's /commit procedure without its full check step."

echo "Batch run: $TASKS_DIR"
print_board

tasks_done=0
while [ "$tasks_done" -lt "$MAX_TASKS" ]; do
  next="$($TP next --dir "$TASKS_DIR")"
  action="$(echo "$next" | jq -r .action)"
  case "$action" in
    all-done) notify "$(tp_t runloop.allDone)"; exit 0 ;;
    blocked)
      id="$(echo "$next" | jq -r .task.id)"
      qpath="$(echo "$next" | jq -r .task.runDir)/questions.md"
      notify "$(tp_t runloop.blocked "id=$id" "path=$qpath")"
      exit 2 ;;
  esac
  id="$(echo "$next" | jq -r .task.id)"
  echo "=== $id ($(echo "$next" | jq -r .task.position)) ==="

  stalls=0
  for run in $(seq 1 "$MAX_RUNS"); do
    before="$(state_of "$id")"
    log="$LOG_DIR/$id-$(date +%Y%m%d-%H%M%S).log"
    raw_log="${log%.log}.jsonl"
    : > "$log"
    : > "$raw_log"
    echo "  запуск $run, состояние: $before → $log"
    start_status_watch "$id" "$log"
    # Сырой stream-json — в .jsonl, читаемая версия — в .log и в консоль по мере работы агента.
    if [ -n "$MODEL" ]; then
      "$AGENT_BIN" -p --force --output-format stream-json --model "$MODEL" "$PROMPT" 2>&1 | tee -a "$raw_log" | humanize_stream | tee -a "$log"
    else
      "$AGENT_BIN" -p --force --output-format stream-json "$PROMPT" 2>&1 | tee -a "$raw_log" | humanize_stream | tee -a "$log"
    fi
    agent_rc=${PIPESTATUS[0]}
    stop_status_watch
    after="$(state_of "$id")"
    echo "  итог запуска $run: $before → $after (код агента: $agent_rc)"
    print_board
    case "$after" in
      done*)
        echo "  $id выполнена."
        docker_cleanup_after_task "$id"
        tasks_done=$((tasks_done + 1))
        continue 2
        ;;
      blocked*) notify "$(tp_t runloop.blockedShort "id=$id")"; exit 2 ;;
    esac
    if [ "$after" = "$before" ]; then
      stalls=$((stalls + 1))
      [ "$stalls" -ge 2 ] && { notify "$(tp_t runloop.stalled "id=$id" "state=$after" "log=$log")"; exit 3; }
      if [ "$agent_rc" -ne 0 ]; then
        echo "  agent exited without progress (code $agent_rc) — pause 30s before retry"
        sleep 30
      fi
    else
      stalls=0
    fi
  done
  notify "$(tp_t runloop.maxRuns "id=$id" "max=$MAX_RUNS")"
  exit 3
done
notify "$(tp_t runloop.maxTasks "max=$MAX_TASKS")"
exit 0
