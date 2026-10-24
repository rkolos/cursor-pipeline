#!/usr/bin/env node
// Task-pipeline state for /task-pipeline. Project-agnostic.
// State: <tasksDir>/.pipeline/state.json, artifacts: <tasksDir>/.pipeline/runs/<taskId>/.
// Active tasks folder per workspace: ~/.cursor/task-pipeline/active.json.
//
//   tp-state.mjs init <tasksDir>                 create/sync state and set active folder
//   tp-state.mjs next [--dir D]                  resume | start | blocked | all-done
//   tp-state.mjs show <taskId|prefix> [--dir D]
//   tp-state.mjs set <taskId|prefix> [--status S] [--phase P] [--force] [--dir D]
//   tp-state.mjs summary [--dir D]
//   tp-state.mjs hook-followup --workspace W     stop-hook: print followup JSON or nothing

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, isAbsolute, join, relative, resolve } from 'node:path';

const HOME_DIR = join(homedir(), '.cursor', 'task-pipeline');
const ACTIVE_PATH = join(HOME_DIR, 'active.json');
const PIPELINE_DIR = '.pipeline';

const STATUSES = ['todo', 'in-progress', 'blocked', 'done'];
const PHASES = ['plan', 'fact', 'awaiting-approval', 'implement', 'check', 'fix', 'commit', 'done'];
const WORK_PHASES = PHASES.filter((phase) => phase !== 'done');
/** Допустимые следующие phase при неизменном status=in-progress (ключ '' = null). */
const PHASE_NEXT = {
  '': ['plan', 'fact'],
  plan: ['fact'],
  fact: ['awaiting-approval', 'implement'],
  'awaiting-approval': ['implement'],
  implement: ['check'],
  check: ['fix', 'commit'],
  fix: ['check', 'commit'],
  commit: ['fix'],
};
const DEFAULT_CONFIG = {
  gateAfterFact: false,
  maxCheckRounds: 2,
  push: true,
  reviewModel: null,
  /** После done stop-hook сразу стартует следующую todo в том же чате (false → только уведомление «новый чат»). */
  continueNextTask: true,
};
const IGNORED_FILES = /^(readme|index|changelog)\.md$/i;
// Статус задачи отражается суффиксом имени файла: 001-foo.md → 001-foo.in-work.md → 001-foo.done.md.
const STATUS_SUFFIX = { todo: '', 'in-progress': '.in-work', blocked: '.in-work', done: '.done' };
const SUFFIX_PATTERN = /\.(in-work|done)$/;

function taskIdOf(file) {
  return basename(file, '.md').replace(SUFFIX_PATTERN, '');
}

/** Infer status/phase for a task file not yet in state.json. */
function statusFromFileName(file) {
  if (file.endsWith('.done.md')) return { status: 'done', phase: 'done' };
  if (file.endsWith('.in-work.md')) return { status: 'in-progress', phase: 'plan' };
  return { status: 'todo', phase: null };
}

function fileNameFor(task) {
  return `${task.id}${STATUS_SUFFIX[task.status]}.md`;
}

// Переписывает ссылки на переименованный файл в соседних .md/.json папки задач (индексы, перекрёстные ссылки).
function rewriteReferences(tasksDir, oldName, newName) {
  const pattern = new RegExp(oldName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
  const touched = [];
  for (const entry of readdirSync(tasksDir, { withFileTypes: true })) {
    if (!entry.isFile() || !/\.(md|json)$/.test(entry.name)) continue;
    const path = join(tasksDir, entry.name);
    const content = readFileSync(path, 'utf8');
    if (!pattern.test(content)) continue;
    pattern.lastIndex = 0;
    writeFileSync(path, content.replace(pattern, newName));
    touched.push(entry.name);
  }
  return touched;
}

function syncFileName(tasksDir, task) {
  const target = fileNameFor(task);
  if (task.file === target) return null;
  const from = join(tasksDir, task.file);
  const to = join(tasksDir, target);
  if (!existsSync(from)) fail(`файл задачи ${task.file} не найден — запустите init, чтобы пересинхронизировать`);
  if (existsSync(to)) fail(`не могу переименовать ${task.file}: ${target} уже существует`);
  renameSync(from, to);
  const previous = task.file;
  task.file = target;
  return { from: previous, to: target, referencesUpdated: rewriteReferences(tasksDir, previous, target) };
}

function fail(message) {
  process.stderr.write(`tp-state: ${message}\n`);
  process.exit(1);
}

function print(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--force') {
      flags.force = true;
    } else if (argv[i].startsWith('--')) {
      flags[argv[i].slice(2)] = argv[i + 1];
      i += 1;
    } else {
      positional.push(argv[i]);
    }
  }
  return { positional, flags };
}

function phaseKey(phase) {
  return phase === null || phase === undefined ? '' : phase;
}

function formatPhase(phase) {
  return phase === null || phase === undefined ? 'null' : phase;
}

/**
 * Проверяет инварианты status/phase и соседство phase при in-progress.
 * Возвращает итоговый phase (с auto для done/todo).
 */
function assertTransition({ prevStatus, prevPhase, nextStatus, nextPhase, phaseFlagPassed, force }) {
  let phase = nextPhase;

  if (force) {
    process.stderr.write('tp-state: предупреждение: --force, проверка переходов отключена\n');
    if (nextStatus === 'done' && !phaseFlagPassed) phase = 'done';
    if (nextStatus === 'todo' && !phaseFlagPassed) phase = null;
    return phase;
  }

  if (nextStatus === 'done') {
    if (!phaseFlagPassed) phase = 'done';
    if (phase !== 'done') {
      fail(`status=done требует phase=done (сейчас phase=${formatPhase(phase)})`);
    }
    return phase;
  }

  if (nextStatus === 'todo') {
    if (!phaseFlagPassed) phase = null;
    if (phase !== null) {
      fail(`status=todo требует phase=null (сейчас phase=${formatPhase(phase)})`);
    }
    return phase;
  }

  if (nextStatus === 'blocked') {
    if (!phaseFlagPassed) {
      if (prevPhase === null || prevPhase === 'done') {
        fail(`status=blocked требует рабочую phase (сейчас phase=${formatPhase(prevPhase)})`);
      }
      phase = prevPhase;
    } else if (!WORK_PHASES.includes(phase)) {
      fail(`status=blocked: phase ${formatPhase(phase)}; ожидалось: ${WORK_PHASES.join(' | ')}`);
    }
    return phase;
  }

  // in-progress
  if (phase === 'done') {
    fail('status=in-progress не допускает phase=done — сначала --status done');
  }
  if (phase !== null && !WORK_PHASES.includes(phase)) {
    fail(`status=in-progress: phase ${formatPhase(phase)}; ожидалось: null | ${WORK_PHASES.join(' | ')}`);
  }

  if (prevStatus === 'in-progress' && nextStatus === 'in-progress' && phase !== prevPhase) {
    const from = phaseKey(prevPhase);
    const allowed = PHASE_NEXT[from] ?? [];
    if (!allowed.includes(phase)) {
      const expect = allowed.length > 0 ? allowed.join(' | ') : '(нет допустимых)';
      fail(
        `запрещён переход phase ${formatPhase(prevPhase)} → ${formatPhase(phase)}; ожидалось: ${expect}`,
      );
    }
  }

  return phase;
}

function workspaceRootOf(dir) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return resolve(dir);
  }
}

function readJson(path, fallback) {
  if (!existsSync(path)) return fallback;
  return JSON.parse(readFileSync(path, 'utf8'));
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function statePath(tasksDir) {
  return join(tasksDir, PIPELINE_DIR, 'state.json');
}

function resolveTasksDir(flagDir) {
  if (flagDir) {
    const dir = resolve(flagDir);
    if (!existsSync(statePath(dir))) fail(`в ${dir} нет ${PIPELINE_DIR}/state.json — сначала init`);
    return dir;
  }
  const workspace = workspaceRootOf(process.cwd());
  const active = readJson(ACTIVE_PATH, {})[workspace];
  if (!active) fail(`для воркспейса ${workspace} нет активной папки задач — запустите init <tasksDir>`);
  return active;
}

function listTaskFiles(tasksDir) {
  return readdirSync(tasksDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
    .map((entry) => entry.name)
    .filter((name) => !name.startsWith('_') && !name.startsWith('.') && !IGNORED_FILES.test(name))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

function describe(tasksDir, state, task) {
  const workspace = workspaceRootOf(tasksDir);
  const rel = (path) => relative(workspace, path) || '.';
  const runDir = join(tasksDir, PIPELINE_DIR, 'runs', task.id);
  return {
    id: task.id,
    status: task.status,
    phase: task.phase,
    position: `${state.tasks.indexOf(task) + 1}/${state.tasks.length}`,
    workspace,
    tasksDir: rel(tasksDir),
    file: rel(join(tasksDir, task.file)),
    runDir: rel(runDir),
    runDirExists: existsSync(runDir),
    config: state.config,
  };
}

function questionsPath(tasksDir, taskId) {
  return join(tasksDir, PIPELINE_DIR, 'runs', taskId, 'questions.md');
}

/** Подставляет «Ответ: <рекомендация>», если Ответ пустой, а в блоке Q есть «Рекомендация: …». */
function applyRecommendedAnswers(tasksDir, taskId) {
  const path = questionsPath(tasksDir, taskId);
  if (!existsSync(path)) return { applied: 0 };
  const original = readFileSync(path, 'utf8');
  const parts = original.split(/(?=^##\s+Q\d+)/m);
  let applied = 0;
  const next = parts.map((part) => {
    if (!/^##\s+Q\d+/im.test(part)) return part;
    const rec = part.match(/Рекомендация:\s*([A-Za-z0-9]+)/i);
    const ansLine = part.match(/^Ответ:\s*(.*)$/m);
    const answer = (ansLine?.[1] ?? '').trim();
    if (answer || !rec) return part;
    applied += 1;
    const filled = `Ответ: ${rec[1]}`;
    if (ansLine) return part.replace(/^Ответ:\s*.*$/m, filled);
    return `${part.replace(/\s*$/, '')}\n${filled}\n`;
  });
  const text = next.join('');
  if (applied > 0 && text !== original) writeFileSync(path, text);
  return { applied };
}

/** true, если questions.md есть и у каждого ## QN… непустой «Ответ: …». */
function questionsAllAnswered(tasksDir, taskId) {
  const path = questionsPath(tasksDir, taskId);
  if (!existsSync(path)) return false;
  const text = readFileSync(path, 'utf8');
  const questionCount = [...text.matchAll(/^##\s+Q\d+/gim)].length;
  const answers = [...text.matchAll(/^Ответ:\s*(.*)$/gim)].map((m) => (m[1] ?? '').trim());
  if (answers.length === 0) return false;
  if (questionCount > 0 && answers.length < questionCount) return false;
  return answers.every((a) => a.length > 0);
}

function tryUnblockFromQuestions(tasksDir, state, first) {
  const rec = applyRecommendedAnswers(tasksDir, first.id);
  if (!questionsAllAnswered(tasksDir, first.id)) return null;
  first.status = 'in-progress';
  syncFileName(tasksDir, first);
  writeJson(statePath(tasksDir), state);
  return {
    action: 'resume',
    unblockedByAnswers: true,
    autoRecommended: rec.applied,
    task: describe(tasksDir, state, first),
  };
}

function loadState(tasksDir) {
  const state = readJson(statePath(tasksDir), null);
  if (!state) fail(`нет ${statePath(tasksDir)}`);
  state.config = { ...DEFAULT_CONFIG, ...state.config };
  return state;
}

function findTask(state, ref) {
  const exact = state.tasks.find((task) => task.id === ref || task.file === ref);
  if (exact) return exact;
  const matches = state.tasks.filter((task) => task.id.startsWith(ref));
  if (matches.length === 1) return matches[0];
  if (matches.length === 0) fail(`задача ${ref} не найдена`);
  fail(`неоднозначно: ${matches.map((task) => task.id).join(', ')}`);
}

function cmdInit(dirArg) {
  if (!dirArg) fail('укажите папку с задачами');
  const requested = isAbsolute(dirArg) ? dirArg : resolve(process.cwd(), dirArg);
  if (!existsSync(requested)) fail(`папка ${requested} не существует`);
  const tasksDir = realpathSync(requested);

  const previous = readJson(statePath(tasksDir), null);
  const known = new Map((previous?.tasks ?? []).map((task) => [task.id, task]));
  const files = listTaskFiles(tasksDir);
  if (files.length === 0) fail(`в ${tasksDir} нет .md файлов задач`);

  const duplicates = files.map(taskIdOf).filter((id, i, ids) => ids.indexOf(id) !== i);
  if (duplicates.length > 0) fail(`несколько файлов для одной задачи: ${[...new Set(duplicates)].join(', ')}`);

  const tasks = files.map((file) => {
    const id = taskIdOf(file);
    const existing = known.get(id);
    if (existing) return { ...existing, file };
    const inferred = statusFromFileName(file);
    return { id, file, status: inferred.status, phase: inferred.phase };
  });

  const inProgress = tasks.filter((task) => task.status === 'in-progress');
  if (inProgress.length > 1) {
    const [keep, ...rest] = inProgress;
    for (const task of rest) {
      task.status = 'blocked';
      if (task.phase === null || task.phase === 'done') task.phase = 'plan';
    }
    process.stderr.write(
      `tp-state: предупреждение: несколько in-progress при init, оставлен ${keep.id}, в blocked: ${rest.map((t) => t.id).join(', ')}\n`,
    );
  }

  const missing = [...known.keys()].filter((id) => !tasks.some((task) => task.id === id));
  const state = {
    version: 1,
    config: { ...DEFAULT_CONFIG, ...previous?.config },
    tasks,
  };
  writeJson(statePath(tasksDir), state);

  const workspace = workspaceRootOf(tasksDir);
  const active = readJson(ACTIVE_PATH, {});
  active[workspace] = tasksDir;
  writeJson(ACTIVE_PATH, active);

  print({
    tasksDir,
    workspace,
    created: !previous,
    total: tasks.length,
    added: tasks.filter((task) => !known.has(task.id)).map((task) => task.id),
    missingTasks: missing,
    config: state.config,
  });
}

function cmdNext(flags) {
  const tasksDir = resolveTasksDir(flags.dir);
  const state = loadState(tasksDir);
  const active = state.tasks.find((task) => task.status === 'in-progress');
  if (active) return print({ action: 'resume', task: describe(tasksDir, state, active) });

  const first = state.tasks.find((task) => task.status !== 'done');
  if (!first) return print({ action: 'all-done', tasksDir });
  if (first.status === 'blocked') {
    // Ответы или «Рекомендация:» в questions.md — продолжать без ожидания пользователя.
    const unblocked = tryUnblockFromQuestions(tasksDir, state, first);
    if (unblocked) return print(unblocked);
    return print({ action: 'blocked', task: describe(tasksDir, state, first) });
  }
  return print({ action: 'start', task: describe(tasksDir, state, first) });
}

function cmdShow(ref, flags) {
  const tasksDir = resolveTasksDir(flags.dir);
  const state = loadState(tasksDir);
  print(describe(tasksDir, state, findTask(state, ref)));
}

function cmdSet(ref, flags) {
  const tasksDir = resolveTasksDir(flags.dir);
  const state = loadState(tasksDir);
  const task = findTask(state, ref);
  const prevStatus = task.status;
  const prevPhase = task.phase;

  if (flags.status !== undefined && !STATUSES.includes(flags.status)) {
    fail(`status: ${STATUSES.join(' | ')}`);
  }
  const phaseFlagPassed = flags.phase !== undefined;
  if (phaseFlagPassed && flags.phase !== 'null' && !PHASES.includes(flags.phase)) {
    fail(`phase: ${PHASES.join(' | ')} | null`);
  }

  const nextStatus = flags.status !== undefined ? flags.status : prevStatus;
  const rawPhase = phaseFlagPassed ? (flags.phase === 'null' ? null : flags.phase) : prevPhase;
  const nextPhase = assertTransition({
    prevStatus,
    prevPhase,
    nextStatus,
    nextPhase: rawPhase,
    phaseFlagPassed,
    force: Boolean(flags.force),
  });

  task.status = nextStatus;
  task.phase = nextPhase;

  if (task.status === 'in-progress') {
    const other = state.tasks.find((item) => item.status === 'in-progress' && item !== task);
    if (other) fail(`задача ${other.id} уже in-progress — одновременно в работе может быть только одна`);
  }
  const renamed = syncFileName(tasksDir, task);
  writeJson(statePath(tasksDir), state);
  print({ ...describe(tasksDir, state, task), ...(renamed ? { renamed } : {}) });
}

function cmdSummary(flags) {
  const tasksDir = resolveTasksDir(flags.dir);
  const state = loadState(tasksDir);
  const counts = Object.fromEntries(STATUSES.map((status) => [status, 0]));
  for (const task of state.tasks) counts[task.status] += 1;
  print({ tasksDir, total: state.tasks.length, ...counts });
}

function cmdHookFollowup(flags) {
  if (!flags.workspace || !existsSync(flags.workspace)) return;
  const workspace = workspaceRootOf(realpathSync(flags.workspace));
  const tasksDir = readJson(ACTIVE_PATH, {})[workspace];
  if (!tasksDir || !existsSync(statePath(tasksDir))) return;
  const state = loadState(tasksDir);
  const active = state.tasks.find((task) => task.status === 'in-progress');
  if (active?.phase === 'awaiting-approval') {
    return print({ notice: `${active.id}: план готов и проверен — нужно подтверждение`, taskId: active.id });
  }
  if (active?.phase && active.phase !== 'done') {
    return print({
      taskId: active.id,
      followup: `Продолжай конвейер задач: прочитай ~/.cursor/commands/task-pipeline.md и продолжи задачу ${active.id} с фазы ${active.phase} (папка задач: ${tasksDir}).`,
    });
  }
  const first = state.tasks.find((task) => task.status !== 'done');
  if (first?.status === 'blocked') {
    applyRecommendedAnswers(tasksDir, first.id);
    if (questionsAllAnswered(tasksDir, first.id)) {
      return print({
        taskId: first.id,
        followup: `Продолжай конвейер задач: в questions.md есть ответы (в т.ч. авто из Рекомендация) — выполни TP set ${first.id} --status in-progress и продолжай с фазы ${first.phase ?? 'implement'} (папка задач: ${tasksDir}). Прочитай ~/.cursor/commands/task-pipeline.md.`,
      });
    }
    return print({ notice: `${first.id}: заблокирована — ответьте на вопросы в questions.md`, taskId: first.id });
  }
  const lastDone = [...state.tasks].reverse().find((task) => task.status === 'done');
  if (first?.status === 'todo' && state.config.continueNextTask !== false) {
    const prev = lastDone ? `${lastDone.id} выполнена. ` : '';
    return print({
      taskId: first.id,
      kind: 'next-task',
      notice: `${prev}беру следующую: ${first.id}`,
      followup: `Продолжай конвейер задач без паузы: ${prev}следующая задача ${first.id}. Выполни TP set ${first.id} --status in-progress --phase plan и пройди полный цикл (план → факт → implement → check → commit) по ~/.cursor/commands/task-pipeline.md (папка задач: ${tasksDir}). Не проси новый чат и не заканчивай ответ вопросом «продолжать?» — следующую задачу запустит stop-hook.`,
    });
  }
  if (lastDone) {
    const tail = first
      ? `следующая: ${first.id} (continueNextTask=false — новый чат, /task-pipeline)`
      : 'все задачи выполнены';
    return print({ notice: `${lastDone.id} выполнена — ${tail}`, taskId: lastDone.id });
  }
  if (!first) {
    return print({ notice: 'все задачи выполнены' });
  }
  print({});
}

const [command, ...rest] = process.argv.slice(2);
const { positional, flags } = parseArgs(rest);
switch (command) {
  case 'init':
    cmdInit(positional[0]);
    break;
  case 'next':
    cmdNext(flags);
    break;
  case 'show':
    if (!positional[0]) fail('укажите задачу');
    cmdShow(positional[0], flags);
    break;
  case 'set':
    if (!positional[0]) fail('укажите задачу');
    cmdSet(positional[0], flags);
    break;
  case 'summary':
    cmdSummary(flags);
    break;
  case 'hook-followup':
    cmdHookFollowup(flags);
    break;
  default:
    fail(
      'команды: init <dir> | next | show <id> | set <id> [--status S] [--phase P] [--force] | summary  (опц. --dir D)',
    );
}
