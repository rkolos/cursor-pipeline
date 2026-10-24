# Spec 01 — Task 06 — i18n foundation (`config.lang`, locales, questions markers)

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **06** · priority **P0**  
**Depends on:** [05](05-hook-followup-tests-ci.md) желательно (тесты не должны сломаться)

## Description

Заложить механику трёх языков без полного перевода текстов (перевод — 07/08).

### 1. Config

- `DEFAULT_CONFIG.lang`: не задавать жёстко `en` в merge так, чтобы сломать old state — при **отсутствии** ключа: `resolveLang(state) = state.config.lang ?? process.env.TP_LANG ?? (state.createdByNewInit ? 'en' : 'ru')`.
- Практичное правило (зафиксировать в коде + how-it-works):
  - `init` **новый** state (created: true) → `config.lang = process.env.TP_LANG || 'en'`
  - `init` merge existing → сохранить `previous.config.lang`; если ключа не было → записать `ru` явно при первой перезаписи config (миграция one-shot).
- CLI: `tp-state set-config --lang en|uk|ru` **или** документировать ручной edit `state.json` + в 09 install flag. Минимум этой задачи: чтение lang в скриптах; запись при init.

### 2. Locale JSON

Создать `scripts/locales/{en,uk,ru}.json` с ключами для:

- `fail.*` / CLI errors (перенести текущие русские строки в `ru.json`, EN/UK — черновики-ключи; UK/EN полные строки можно заполнить заглушками-English в 06 и заменить в 07/08, **или** сразу нормальный EN + UK для коротких fail-сообщений).
- `followup.resume`, `followup.nextTask`, `followup.unblock`, `notice.*` из `cmdHookFollowup` и `hook.mjs` notify titles.

Helper `loadLocale(lang)` рядом с tp-state/hook (shared tiny `scripts/i18n.mjs`).

### 3. questions.md markers

Расширить regex:

- Recommendation: `Рекомендация|Recommendation|Рекомендація`
- Answer: `Ответ|Answer|Відповідь`

`applyRecommendedAnswers` / `questionsAllAnswered` используют любой вариант; при auto-fill писать метку **в том же языке, что у блока** (если была `Recommendation:` — писать `Answer:`; если `Рекомендация:` — `Ответ:`).

### 4. Directory layout (переезд без смены поведения install)

- Перенести текущие `commands/*.md` → `commands/ru/*.md`.
- Перенести `rules/task-pipeline-*.mdc` → `rules/ru/`.
- В корне `commands/` и `rules/` оставить **только** то, что install ожидает: либо install читает lang и линкует из `commands/<lang>/`, либо временные symlink `commands/task-pipeline.md` → `ru/…` для dev. Канон после 06: install линкует из `commands/ru/` пока нет `--lang` (default install lang = `en` в 09; в 06 default symlink target = `ru` для zero-break **или** `en` если 07 уже готов — **в 06 сохранить runtime RU paths working**).

Рекомендация плана: в 06 сделать layout + loader; install ещё линкует `ru` (как сейчас по смыслу). 09 переключает default install на `en`.

## Files

- Create: `scripts/i18n.mjs`, `scripts/locales/en.json`, `uk.json`, `ru.json`
- Modify: `scripts/tp-state.mjs`, `scripts/hook.mjs` (и при необходимости `run-loop.sh` prompt — позже 07)
- Move: `commands/*` → `commands/ru/`, `rules/*` → `rules/ru/`
- Modify: `install.sh` — пути к `commands/ru`, `rules/ru`
- Modify: `tests/*` — Recommendation/Answer synonyms; HOME isolation если уже есть
- Modify: `docs/how-it-works.md`, `CONTRIBUTING.md`

## Pay attention

- Не сломать TRIGGER `/task-pipeline` в hook.
- JSON locale: только плоские/один уровень вложенности ключей — без i18n framework.
- Followup текст в 06 может остаться RU через `ru.json`; EN/UK keys указывают на те же RU строки временно **нежелательно** — лучше короткие EN stubs в en/uk.

## Definition of done

- [ ] New init пишет `lang` (default en для new; old без lang → ru при load/migrate).
- [ ] `questions.md` с `Recommendation:` / `Answer:` разблокирует как RU-метки (тест).
- [ ] `commands/ru` + `rules/ru` установлены install.sh; `./tests/run.sh` зелёный.
- [ ] Shared `i18n.mjs` используется tp-state и hook.
