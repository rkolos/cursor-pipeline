#!/usr/bin/env node
// Merge task-pipeline hook entries into ~/.cursor/hooks.json without touching other hooks.
// Usage: node merge-hooks.mjs --target <hooks.json> --fragment <fragment.json> [--uninstall]

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const MARKER = 'task-pipeline/hook.sh';

function parseArgs(argv) {
  const flags = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--uninstall') flags.uninstall = true;
    else if (argv[i].startsWith('--')) {
      flags[argv[i].slice(2)] = argv[i + 1];
      i += 1;
    }
  }
  return flags;
}

function isPipelineHook(entry) {
  return String(entry?.command ?? '').includes(MARKER);
}

function loadJson(path, fallback) {
  if (!existsSync(path)) return fallback;
  return JSON.parse(readFileSync(path, 'utf8'));
}

function main() {
  const { target, fragment, uninstall } = parseArgs(process.argv.slice(2));
  if (!target) {
    process.stderr.write('merge-hooks: --target <path> is required\n');
    process.exit(1);
  }

  const base = loadJson(target, { version: 1, hooks: {} });
  if (!base.hooks || typeof base.hooks !== 'object') base.hooks = {};

  if (uninstall) {
    for (const event of Object.keys(base.hooks)) {
      const list = base.hooks[event];
      if (!Array.isArray(list)) continue;
      base.hooks[event] = list.filter((entry) => !isPipelineHook(entry));
      if (base.hooks[event].length === 0) delete base.hooks[event];
    }
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, `${JSON.stringify(base, null, 2)}\n`);
    return;
  }

  if (!fragment || !existsSync(fragment)) {
    process.stderr.write('merge-hooks: --fragment <path> is required (unless --uninstall)\n');
    process.exit(1);
  }

  const piece = JSON.parse(readFileSync(fragment, 'utf8'));
  const incoming = piece.hooks ?? piece;
  if (!incoming || typeof incoming !== 'object') {
    process.stderr.write('merge-hooks: fragment has no hooks object\n');
    process.exit(1);
  }

  for (const [event, entries] of Object.entries(incoming)) {
    if (!Array.isArray(entries)) continue;
    const pipelineEntries = entries.filter(isPipelineHook);
    if (pipelineEntries.length === 0) continue;

    const current = Array.isArray(base.hooks[event]) ? base.hooks[event] : [];
    const others = current.filter((entry) => !isPipelineHook(entry));
    // Replace pipeline entries so reinstall picks up timeout/loop_limit/command updates.
    base.hooks[event] = [...others, ...pipelineEntries];
  }

  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, `${JSON.stringify(base, null, 2)}\n`);
}

main();
