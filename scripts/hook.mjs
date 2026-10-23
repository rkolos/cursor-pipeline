#!/usr/bin/env node
// Cursor hooks for /task-pipeline.
//   hook.mjs prompt   — beforeSubmitPrompt: remembers the chat where /task-pipeline was started.
//   hook.mjs response — afterAgentResponse: records whether the agent ended with a user-facing question.
//   hook.mjs stop     — stop: continues the current phase or (if continueNextTask) the next todo after done;
//                       skips followup when a human is needed (real question, plan gate, blocked).
// Failures never block the agent: on error the hook returns an empty result.

import { execFileSync, spawn } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { homedir, platform } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HOME_DIR = join(homedir(), '.cursor', 'task-pipeline');
const SESSIONS_DIR = join(HOME_DIR, 'sessions');
const STATE_SCRIPT = join(dirname(fileURLToPath(import.meta.url)), 'tp-state.mjs');
const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const TRIGGER = /(^|\s)\/task-pipeline(\s|$)/;

function respond(value) {
  process.stdout.write(JSON.stringify(value));
  process.exit(0);
}

function readInput() {
  try {
    return JSON.parse(readFileSync(0, 'utf8') || '{}');
  } catch {
    return {};
  }
}

function sessionPath(conversationId) {
  return join(SESSIONS_DIR, `${String(conversationId).replace(/[^\w-]/g, '_')}.json`);
}

function readSession(conversationId) {
  const path = sessionPath(conversationId);
  return existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : null;
}

function writeSession(conversationId, session) {
  mkdirSync(SESSIONS_DIR, { recursive: true });
  writeFileSync(sessionPath(conversationId), JSON.stringify(session));
}

function pruneSessions() {
  if (!existsSync(SESSIONS_DIR)) return;
  const now = Date.now();
  for (const name of readdirSync(SESSIONS_DIR)) {
    const path = join(SESSIONS_DIR, name);
    if (now - statSync(path).mtimeMs > SESSION_TTL_MS) rmSync(path, { force: true });
  }
}

function notify(message) {
  if (platform() !== 'darwin' || process.env.TP_NOTIFY === '0') return;
  const escaped = message.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  const child = spawn('osascript', ['-e', `display notification "${escaped}" with title "task-pipeline" sound name "Glass"`], {
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
}

// Rhetorical pipeline questions ("Continue?", "Proceed to next task?") are not user-facing:
// the next step is already in state.json. Some models end task summaries this way; without this
// exception the stop-hook would suppress followup and stall the pipeline.
const CONTINUE_QUESTION =
  /(?<![a-zа-яё])(продолж|перейти|переход|следующ|дальше|начина|начать|старт|запус|брать|взять|идти|continue|proceed|next\s+task|go\s+ahead|move\s+on|start)/i;

function endsWithQuestion(text) {
  const lines = String(text ?? '')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('```'));
  const last = lines.at(-1) ?? '';
  if (!/\?\**\s*$/.test(last)) return false;
  const lastSentence = last.split(/[.!?]\s+/).at(-1) ?? last;
  return !CONTINUE_QUESTION.test(lastSentence);
}

function onPrompt(input) {
  if (input.conversation_id && TRIGGER.test(String(input.prompt ?? ''))) {
    writeSession(input.conversation_id, { workspaceRoots: input.workspace_roots ?? [], at: new Date().toISOString() });
    pruneSessions();
  } else if (input.conversation_id) {
    const session = readSession(input.conversation_id);
    if (session?.askedQuestion) writeSession(input.conversation_id, { ...session, askedQuestion: false });
  }
  respond({ continue: true });
}

function onResponse(input) {
  const session = input.conversation_id ? readSession(input.conversation_id) : null;
  if (session) writeSession(input.conversation_id, { ...session, askedQuestion: endsWithQuestion(input.text) });
  respond({});
}

function onStop(input) {
  if (input.status !== 'completed' || !input.conversation_id) respond({});
  const session = readSession(input.conversation_id);
  if (!session) respond({});

  let result = {};
  for (const workspace of [...(input.workspace_roots ?? []), ...session.workspaceRoots]) {
    const output = execFileSync(process.execPath, [STATE_SCRIPT, 'hook-followup', '--workspace', workspace], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (output) {
      result = JSON.parse(output);
      break;
    }
  }

  let notice = result.notice;
  // Previous task is done — no open question; rhetorical "continue?" must not block next-task followup.
  if (result.followup && session.askedQuestion && result.kind !== 'next-task') {
    notice = `${result.taskId}: агент задал вопрос в чате — нужен ваш ответ`;
    result.followup = undefined;
  }
  if (notice && notice !== session.lastNotice) {
    notify(notice);
    writeSession(input.conversation_id, { ...session, lastNotice: notice });
  }
  respond(result.followup ? { followup_message: result.followup } : {});
}

try {
  const input = readInput();
  if (process.argv[2] === 'prompt') onPrompt(input);
  if (process.argv[2] === 'response') onResponse(input);
  if (process.argv[2] === 'stop') onStop(input);
  respond({});
} catch {
  respond(process.argv[2] === 'prompt' ? { continue: true } : {});
}
