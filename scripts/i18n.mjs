// Shared locale loader for tp-state / hook. Flat JSON keys only. No npm deps.
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const LOCALES_DIR = join(dirname(fileURLToPath(import.meta.url)), 'locales');
export const LANGS = ['en', 'uk', 'ru'];
const cache = new Map();

export function normalizeLang(lang) {
  const value = String(lang ?? '')
    .trim()
    .toLowerCase();
  return LANGS.includes(value) ? value : null;
}

/** New init → en (or TP_LANG); existing state without lang → ru. */
export function resolveLang(config = {}, { isNewInit = false } = {}) {
  return (
    normalizeLang(config.lang) ||
    normalizeLang(process.env.TP_LANG) ||
    (isNewInit ? 'en' : 'ru')
  );
}

export function loadLocale(lang) {
  const code = normalizeLang(lang) || 'en';
  if (cache.has(code)) return cache.get(code);
  const path = join(LOCALES_DIR, `${code}.json`);
  if (!existsSync(path)) {
    const fallback = join(LOCALES_DIR, 'en.json');
    const data = JSON.parse(readFileSync(fallback, 'utf8'));
    cache.set(code, data);
    return data;
  }
  const data = JSON.parse(readFileSync(path, 'utf8'));
  cache.set(code, data);
  return data;
}

export function t(lang, key, vars = {}) {
  const primary = loadLocale(lang);
  const fallback = lang === 'en' ? primary : loadLocale('en');
  let text = primary[key] ?? fallback[key] ?? key;
  for (const [name, value] of Object.entries(vars)) {
    text = text.replaceAll(`{${name}}`, String(value));
  }
  return text;
}
