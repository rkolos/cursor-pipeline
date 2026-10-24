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
//   tp-state.mjs doctor [--dir D] [--fix]       report / repair state↔files
//   tp-state.mjs hook-followup --workspace W     stop-hook: print followup JSON or nothing

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { normalizeLang, resolveLang, t } from './i18n.mjs';

const HOME_DIR = join(homedir(), '.cursor', 'task-pipeline');
const ACTIVE_PATH = join(HOME_DIR, 'active.json');
const PIPELINE_DIR = '.pipeline';
/** CLI message language until a state is loaded (TP_LANG or en). */
let cliLang = resolveLang({}, { isNewInit: true });

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
  if (!existsSync(from)) failKey('fail.taskFileMissing', { file: task.file });
  if (existsSync(to)) failKey('fail.renameExists', { from: task.file, to: target });
  renameSync(from, to);
  const previous = task.file;
  task.file = target;
  return { from: previous, to: target, referencesUpdated: rewriteReferences(tasksDir, previous, target) };
}

function fail(message) {
  process.stderr.write(`tp-state: ${message}\n`);
  process.exit(1);
}

function failKey(key, vars) {
  fail(t(cliLang, key, vars));
}

function useLangFromConfig(config) {
  cliLang = resolveLang(config ?? {}, { isNewInit: false });
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
    } else if (argv[i] === '--fix') {
      flags.fix = true;
    } else if (argv[i].startsWith('--')) {
      flags[argv[i].slice(2)] = argv[i + 1];
      i += 1;
    } else {
      positional.push(argv[i]);
    }
  }
  return { positional, flags };
}

/** Current status/phase illegal under the same invariants as assertTransition (no adjacent-phase check). */
function phaseStatusIllegalReason(task) {
  const { status, phase } = task;
  if (status === 'done') {
    if (phase !== 'done') return `done requires phase=done (got ${formatPhase(phase)})`;
    return null;
  }
  if (status === 'todo') {
    if (phase !== null) return `todo requires phase=null (got ${formatPhase(phase)})`;
    return null;
  }
  if (status === 'blocked') {
    if (!WORK_PHASES.includes(phase)) {
      return `blocked requires work phase (got ${formatPhase(phase)})`;
    }
    return null;
  }
  if (status === 'in-progress') {
    if (phase === 'done') return 'in-progress cannot use phase=done';
    if (phase !== null && !WORK_PHASES.includes(phase)) {
      return `in-progress: invalid phase ${formatPhase(phase)}`;
    }
    return null;
  }
  return `unknown status ${status}`;
}

function collectDoctorProblems(tasksDir, state) {
  const problems = [];
  const info = [];
  const lang = resolveLang(state.config ?? {}, { isNewInit: false });

  const inProgress = state.tasks.filter((task) => task.status === 'in-progress');
  if (inProgress.length > 1) {
    problems.push({
      kind: 'multipleInProgress',
      ids: inProgress.map((task) => task.id),
      message: t(lang, 'doctor.multipleInProgress', { ids: inProgress.map((task) => task.id).join(', ') }),
    });
  }

  for (const task of state.tasks) {
    const expected = fileNameFor(task);
    const path = join(tasksDir, task.file);
    if (!existsSync(path)) {
      problems.push({
        kind: 'missingTaskFile',
        id: task.id,
        file: task.file,
        message: t(lang, 'doctor.missingTaskFile', { id: task.id, file: task.file }),
      });
    } else if (task.file !== expected) {
      problems.push({
        kind: 'fileStatusMismatch',
        id: task.id,
        status: task.status,
        file: task.file,
        expected,
        message: t(lang, 'doctor.fileStatusMismatch', {
          id: task.id,
          file: task.file,
          expected,
          status: task.status,
        }),
      });
    }

    const illegal = phaseStatusIllegalReason(task);
    if (illegal) {
      problems.push({
        kind: 'phaseStatusIllegal',
        id: task.id,
        status: task.status,
        phase: task.phase,
        detail: illegal,
        message: t(lang, 'doctor.phaseStatusIllegal', { id: task.id, detail: illegal }),
      });
    }

    if (
      task.status === 'blocked' &&
      existsSync(questionsPath(tasksDir, task.id)) &&
      !questionsAllAnswered(tasksDir, task.id)
    ) {
      problems.push({
        kind: 'questionsBlockedUnanswered',
        id: task.id,
        message: t(lang, 'doctor.questionsBlockedUnanswered', { id: task.id }),
      });
    }
  }

  const runsRoot = join(tasksDir, PIPELINE_DIR, 'runs');
  if (existsSync(runsRoot)) {
    const known = new Set(state.tasks.map((task) => task.id));
    for (const entry of readdirSync(runsRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      if (known.has(entry.name)) continue;
      info.push({
        kind: 'orphanRunDirs',
        id: entry.name,
        message: t(lang, 'doctor.orphanRunDir', { id: entry.name }),
      });
    }
  }

  return { lang, problems, info };
}

function applyDoctorFixes(tasksDir, state, problems) {
  const fixed = [];
  const lang = resolveLang(state.config ?? {}, { isNewInit: false });

  for (const problem of problems) {
    if (problem.kind === 'fileStatusMismatch') {
      const task = state.tasks.find((item) => item.id === problem.id);
      if (!task) continue;
      // Safer recovery: on-disk `.done` + status todo → promote status (do not rename away from done).
      if (task.file.endsWith('.done.md') && task.status === 'todo') {
        task.status = 'done';
        task.phase = 'done';
        fixed.push({ kind: 'fileStatusMismatch', id: task.id, action: 'status→done', message: t(lang, 'doctor.fixedStatusDone', { id: task.id }) });
        continue;
      }
      try {
        const renamed = syncFileName(tasksDir, task);
        if (renamed) {
          fixed.push({
            kind: 'fileStatusMismatch',
            id: task.id,
            action: 'syncFileName',
            from: renamed.from,
            to: renamed.to,
            message: t(lang, 'doctor.fixedRename', { id: task.id, from: renamed.from, to: renamed.to }),
          });
        }
      } catch {
        // leave for re-scan / report
      }
    }
  }

  const multi = problems.find((problem) => problem.kind === 'multipleInProgress');
  if (multi) {
    const inProgress = state.tasks.filter((task) => task.status === 'in-progress');
    if (inProgress.length > 1) {
      const [keep, ...rest] = inProgress;
      for (const task of rest) {
        task.status = 'blocked';
        if (task.phase === null || task.phase === 'done') task.phase = 'plan';
        const renamed = syncFileName(tasksDir, task);
        fixed.push({
          kind: 'multipleInProgress',
          id: task.id,
          action: '→blocked',
          keep: keep.id,
          renamed: renamed ?? null,
          message: t(lang, 'doctor.fixedMultiBlocked', { id: task.id, keep: keep.id }),
        });
      }
    }
  }

  if (fixed.length > 0) writeJson(statePath(tasksDir), state);
  return fixed;
}

function cmdDoctor(flags) {
  const tasksDir = resolveTasksDir(flags.dir);
  const state = loadState(tasksDir);
  const doFix = Boolean(flags.fix);
  let collected = collectDoctorProblems(tasksDir, state);
  let fixed = [];
  if (doFix && collected.problems.length > 0) {
    fixed = applyDoctorFixes(tasksDir, state, collected.problems);
    // Reload from disk after renames / writes
    const refreshed = loadState(tasksDir);
    Object.assign(state, refreshed);
    state.tasks = refreshed.tasks;
    collected = collectDoctorProblems(tasksDir, state);
  }
  const report = {
    tasksDir,
    lang: collected.lang,
    fix: doFix,
    fixed,
    problems: collected.problems,
    info: collected.info,
  };
  print(report);
  process.exit(collected.problems.length === 0 ? 0 : 1);
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
    process.stderr.write(`tp-state: ${t(cliLang, 'warn.force')}\n`);
    if (nextStatus === 'done' && !phaseFlagPassed) phase = 'done';
    if (nextStatus === 'todo' && !phaseFlagPassed) phase = null;
    return phase;
  }

  if (nextStatus === 'done') {
    if (!phaseFlagPassed) phase = 'done';
    if (phase !== 'done') {
      failKey('fail.doneNeedsPhaseDone', { phase: formatPhase(phase) });
    }
    return phase;
  }

  if (nextStatus === 'todo') {
    if (!phaseFlagPassed) phase = null;
    if (phase !== null) {
      failKey('fail.todoNeedsPhaseNull', { phase: formatPhase(phase) });
    }
    return phase;
  }

  if (nextStatus === 'blocked') {
    if (!phaseFlagPassed) {
      if (prevPhase === null || prevPhase === 'done') {
        failKey('fail.blockedNeedsWorkPhase', { phase: formatPhase(prevPhase) });
      }
      phase = prevPhase;
    } else if (!WORK_PHASES.includes(phase)) {
      failKey('fail.blockedPhaseInvalid', { phase: formatPhase(phase), expected: WORK_PHASES.join(' | ') });
    }
    return phase;
  }

  // in-progress
  if (phase === 'done') {
    failKey('fail.inProgressNoDonePhase');
  }
  if (phase !== null && !WORK_PHASES.includes(phase)) {
    failKey('fail.inProgressPhaseInvalid', { phase: formatPhase(phase), expected: WORK_PHASES.join(' | ') });
  }

  if (prevStatus === 'in-progress' && nextStatus === 'in-progress' && phase !== prevPhase) {
    const from = phaseKey(prevPhase);
    const allowed = PHASE_NEXT[from] ?? [];
    if (!allowed.includes(phase)) {
      const expect = allowed.length > 0 ? allowed.join(' | ') : '(нет допустимых)';
      failKey('fail.phaseTransition', {
        from: formatPhase(prevPhase),
        to: formatPhase(phase),
        expected: expect,
      });
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
    if (!existsSync(statePath(dir))) {
      failKey('fail.noStateInDir', { dir, pipeline: PIPELINE_DIR });
    }
    return dir;
  }
  const workspace = workspaceRootOf(process.cwd());
  const active = readJson(ACTIVE_PATH, {})[workspace];
  if (!active) failKey('fail.noActiveFolder', { workspace });
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

const REC_LABEL = 'Рекомендация|Recommendation|Рекомендація';
const ANS_LABEL = 'Ответ|Answer|Відповідь';
const ANSWER_FOR_REC = {
  Рекомендация: 'Ответ',
  Recommendation: 'Answer',
  Рекомендація: 'Відповідь',
};

/** Подставляет Answer/Ответ/Відповідь из Recommendation/…, сохраняя язык метки. */
function applyRecommendedAnswers(tasksDir, taskId) {
  const path = questionsPath(tasksDir, taskId);
  if (!existsSync(path)) return { applied: 0 };
  const original = readFileSync(path, 'utf8');
  const parts = original.split(/(?=^##\s+Q\d+)/m);
  let applied = 0;
  const next = parts.map((part) => {
    if (!/^##\s+Q\d+/im.test(part)) return part;
    const rec = part.match(new RegExp(`(${REC_LABEL}):\\s*([A-Za-z0-9]+)`, 'i'));
    const ansLine = part.match(new RegExp(`^(${ANS_LABEL}):\\s*(.*)$`, 'm'));
    const answer = (ansLine?.[2] ?? '').trim();
    if (answer || !rec) return part;
    applied += 1;
    const recLabel = Object.keys(ANSWER_FOR_REC).find((label) => label.toLowerCase() === rec[1].toLowerCase()) ?? 'Рекомендация';
    const ansLabel = ANSWER_FOR_REC[recLabel];
    const filled = `${ansLabel}: ${rec[2]}`;
    if (ansLine) return part.replace(new RegExp(`^(${ANS_LABEL}):\\s*.*$`, 'm'), filled);
    return `${part.replace(/\s*$/, '')}\n${filled}\n`;
  });
  const text = next.join('');
  if (applied > 0 && text !== original) writeFileSync(path, text);
  return { applied };
}

/** true, если questions.md есть и у каждого ## QN… непустой Answer/Ответ/Відповідь. */
function questionsAllAnswered(tasksDir, taskId) {
  const path = questionsPath(tasksDir, taskId);
  if (!existsSync(path)) return false;
  const text = readFileSync(path, 'utf8');
  const questionCount = [...text.matchAll(/^##\s+Q\d+/gim)].length;
  const answers = [...text.matchAll(new RegExp(`^(?:${ANS_LABEL}):\\s*(.*)$`, 'gim'))].map((m) => (m[1] ?? '').trim());
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
  if (!state) failKey('fail.noStateFile', { path: statePath(tasksDir) });
  state.config = { ...DEFAULT_CONFIG, ...state.config };
  useLangFromConfig(state.config);
  return state;
}

function findTask(state, ref) {
  const exact = state.tasks.find((task) => task.id === ref || task.file === ref);
  if (exact) return exact;
  const matches = state.tasks.filter((task) => task.id.startsWith(ref));
  if (matches.length === 1) return matches[0];
  if (matches.length === 0) failKey('fail.taskNotFound', { ref });
  failKey('fail.taskAmbiguous', { ids: matches.map((task) => task.id).join(', ') });
}

function cmdInit(dirArg) {
  if (!dirArg) failKey('fail.needTasksDir');
  const requested = isAbsolute(dirArg) ? dirArg : resolve(process.cwd(), dirArg);
  if (!existsSync(requested)) failKey('fail.dirMissing', { dir: requested });
  const tasksDir = realpathSync(requested);

  const previous = readJson(statePath(tasksDir), null);
  const isNew = !previous;
  const known = new Map((previous?.tasks ?? []).map((task) => [task.id, task]));
  const files = listTaskFiles(tasksDir);
  if (files.length === 0) failKey('fail.noTaskFiles', { dir: tasksDir });

  const duplicates = files.map(taskIdOf).filter((id, i, ids) => ids.indexOf(id) !== i);
  if (duplicates.length > 0) {
    failKey('fail.duplicateTaskFiles', { ids: [...new Set(duplicates)].join(', ') });
  }

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
      `tp-state: ${t(cliLang, 'warn.multiInProgress', { keep: keep.id, rest: rest.map((task) => task.id).join(', ') })}\n`,
    );
  }

  const missing = [...known.keys()].filter((id) => !tasks.some((task) => task.id === id));
  const config = { ...DEFAULT_CONFIG, ...previous?.config };
  if (isNew) {
    config.lang = normalizeLang(process.env.TP_LANG) || 'en';
  } else if (!normalizeLang(config.lang)) {
    config.lang = 'ru';
  }
  useLangFromConfig(config);
  const state = {
    version: 1,
    config,
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
    failKey('fail.badStatus', { expected: STATUSES.join(' | ') });
  }
  const phaseFlagPassed = flags.phase !== undefined;
  if (phaseFlagPassed && flags.phase !== 'null' && !PHASES.includes(flags.phase)) {
    failKey('fail.badPhase', { expected: PHASES.join(' | ') });
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
    if (other) failKey('fail.otherInProgress', { id: other.id });
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
  const lang = resolveLang(state.config, { isNewInit: false });
  const withLang = (obj) => ({ ...obj, lang });
  const active = state.tasks.find((task) => task.status === 'in-progress');
  if (active?.phase === 'awaiting-approval') {
    return print(
      withLang({ notice: t(lang, 'notice.awaitingApproval', { id: active.id }), taskId: active.id }),
    );
  }
  if (active?.phase && active.phase !== 'done') {
    return print(
      withLang({
        taskId: active.id,
        followup: t(lang, 'followup.resume', { id: active.id, phase: active.phase, tasksDir }),
      }),
    );
  }
  const first = state.tasks.find((task) => task.status !== 'done');
  if (first?.status === 'blocked') {
    applyRecommendedAnswers(tasksDir, first.id);
    if (questionsAllAnswered(tasksDir, first.id)) {
      return print(
        withLang({
          taskId: first.id,
          followup: t(lang, 'followup.unblock', {
            id: first.id,
            phase: first.phase ?? 'implement',
            tasksDir,
          }),
        }),
      );
    }
    return print(withLang({ notice: t(lang, 'notice.blocked', { id: first.id }), taskId: first.id }));
  }
  const lastDone = [...state.tasks].reverse().find((task) => task.status === 'done');
  if (first?.status === 'todo' && state.config.continueNextTask !== false) {
    const prev = lastDone ? t(lang, 'followup.prevDone', { id: lastDone.id }) : '';
    return print(
      withLang({
        taskId: first.id,
        kind: 'next-task',
        notice: t(lang, 'notice.nextTask', { prev, id: first.id }),
        followup: t(lang, 'followup.nextTask', { prev, id: first.id, tasksDir }),
      }),
    );
  }
  if (lastDone) {
    const tail = first
      ? t(lang, 'notice.tailNextFalse', { id: first.id })
      : t(lang, 'notice.tailAllDone');
    return print(
      withLang({ notice: t(lang, 'notice.doneContinueFalse', { id: lastDone.id, tail }), taskId: lastDone.id }),
    );
  }
  if (!first) {
    return print(withLang({ notice: t(lang, 'notice.allDone') }));
  }
  print(withLang({}));
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
    if (!positional[0]) failKey('fail.needTaskRef');
    cmdShow(positional[0], flags);
    break;
  case 'set':
    if (!positional[0]) failKey('fail.needTaskRef');
    cmdSet(positional[0], flags);
    break;
  case 'summary':
    cmdSummary(flags);
    break;
  case 'doctor':
    cmdDoctor(flags);
    break;
  case 'hook-followup':
    cmdHookFollowup(flags);
    break;
  default:
    failKey('fail.usage');
}
