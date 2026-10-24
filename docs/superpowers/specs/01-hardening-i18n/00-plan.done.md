# cursor-pipeline — Hardening + i18n (EN / UK / RU) — Implementation Plan

> **For agentic workers:** Use `/task-pipeline` on this folder (or subagent-driven-development). Tracking: checkboxes in each `01`–`11` task file. Status suffixes (`.in-work.md` / `.done.md`) are managed by `tp-state`.

**Goal:** Укрепить гарантии state-машины и install/hooks, добавить локали **English** и **Ukrainian** (русский сохранить), чтобы публичный репозиторий и агентские промпты работали на выбранном языке без потери авторазблокировки `questions.md` и stop-hook followup.

**Architecture:** Ядро остаётся Node-скриптами (`tp-state.mjs`, `hook.mjs`, `merge-hooks.mjs`, `run-loop.sh`) + markdown-команды/rules. Жёсткие гарантии — в скриптах (валидация переходов, infer статуса из имён файлов, обновление hooks при reinstall, `doctor`). Мягкие контракты агента (порядок done/commit) — в `commands/` + `rules/`. i18n: `config.lang` ∈ `en|uk|ru`, каталоги строк для CLI/hook/followup, зеркала `commands/<lang>/` и `rules/<lang>/`, парсер `questions.md` принимает метки всех трёх языков.

**Tech Stack:** Node 18+ · bash · Cursor hooks (`hooks.json`) · существующие shell-тесты в `tests/` · без новых npm-зависимостей.

**Source review:** выводы аудита (валидация state, done-до-commit, init без `.in-work`, merge-hooks append-only, эвристика вопросов, RU-only промпты) · текущий код `scripts/`, `commands/`, `rules/`, `install.sh`.

---

## Roadmap

| # | File | Priority | Scope |
|---|---|---|---|
| 01 | [01-state-transition-validation.done.md](01-state-transition-validation.done.md) | P0 | Допустимые `status`/`phase` в `tp-state set` |
| 02 | [02-init-infer-status-from-filename.done.md](02-init-infer-status-from-filename.done.md) | P0 | Infer из суффиксов при `init`: `.in-work`→`in-progress`, `.done`→`done`, plain→`todo` (`blocked` из имени не восстанавливается) |
| 03 | [03-commit-before-done.md](03-commit-before-done.md) | P0 | `done` только после успешного commit (+ правило/команда) |
| 04 | [04-merge-hooks-update.md](04-merge-hooks-update.md) | P0 | Reinstall обновляет pipeline-hooks по marker |
| 05 | [05-hook-followup-tests-ci.md](05-hook-followup-tests-ci.md) | P0 | Тесты `hook-followup` + GitHub Actions |
| 06 | [06-i18n-foundation.md](06-i18n-foundation.md) | P0 | `config.lang`, каталоги строк, парсер Q-меток EN/UK/RU |
| 07 | [07-locale-english.md](07-locale-english.md) | P0 | Полный EN: commands, rules, followup/CLI |
| 08 | [08-locale-ukrainian.md](08-locale-ukrainian.md) | P0 | Полный UK: commands, rules, followup/CLI |
| 09 | [09-install-lang-and-docs.md](09-install-lang-and-docs.md) | P1 | `install.sh --lang`, README/how-it-works, примеры |
| 10 | [10-tp-state-doctor.md](10-tp-state-doctor.md) | P1 | `tp-state doctor` / рассинхрон file↔status |
| 11 | [11-acceptance-pass.md](11-acceptance-pass.md) | P1 | Сквозная приёмка hardening + трёх локалей |

---

## Фазы

1. **Hardening (01–05)** — state и hooks надёжнее; тесты/CI ловят регрессии.
2. **i18n (06–08)** — foundation, затем EN и UK (RU = baseline, не ломать).
3. **DX (09–11)** — install/docs, doctor, acceptance.

Порядок внутри фазы — по номерам файлов. Не начинать 07/08 до зелёного 06. Не начинать 11 до 01–10 (или явно отметить skip с обоснованием в `questions.md`).

---

## Scope

**In:**

- Валидация переходов и infer статуса из имён файлов.
- Контракт commit → затем `done` (команда + always-on rule).
- Идемпотентный update hooks при `./install.sh`.
- Расширенные тесты followup + CI `./tests/run.sh`.
- Три локали агентских текстов: `en`, `uk`, `ru`.
- `config.lang`, install flag, документация.
- `tp-state doctor`.

**Out (следующий эпик, не эта папка):**

- Граф зависимостей задач (`dependsOn`).
- Per-task override `maxCheckRounds` / `push`.
- HTML-дашборд / Linux `notify-send` (кроме упоминания в docs как future).
- Жёсткий subprocess-gate фаз (запрет tool calls вне whitelist).
- Перевод `CONTRIBUTING.md` / LICENSE comments (достаточно EN docs + локализованных agent surfaces).

---

## Global Constraints

- Без новых runtime-зависимостей npm; только Node stdlib + bash.
- `install.sh` остаётся идемпотентным; чужие hooks не удаляются.
- Ошибки hook никогда не блокируют агента (`catch` → пустой JSON / `{continue:true}`).
- Русский baseline: существующие пути `commands/*.md` и `rules/task-pipeline-*.mdc` либо становятся symlink на `ru/`, либо остаются каноном для `lang=ru` — выбрать один подход в задаче 06 и не менять в 07–09.
- Парсер `questions.md`: принимать `Рекомендация` / `Recommendation` / `Рекомендація` и `Ответ` / `Answer` / `Відповідь` (регистр-insensitive по первой букве как сейчас для RU).
- Default для **нового** `init` без явного lang: `en` (публичный репозиторий). Уже существующий `state.json` без `lang` → при load считать `ru` (обратная совместимость установленных пользователей).
- Focused checks: `./tests/run.sh` + `node --check` на изменённых `.mjs`. Полный smoke IDE не обязателен в каждой задаче — только в 11.
- Документы пишутся начисто (без «раньше было / устарело»).
- Коммиты — только по запросу пользователя / фазе commit конвейера; не пушить секреты.

---

## Дизайн i18n (кратко)

```
config.lang: "en" | "uk" | "ru"

commands/
  en/task-pipeline.md  tp-fact.md  tp-check.md
  uk/...
  ru/...          # содержимое нынешних commands/*.md
rules/
  en/task-pipeline-*.mdc
  uk/...
  ru/...
scripts/locales/
  en.json  uk.json  ru.json   # notice/followup/CLI fail messages
```

`install.sh --lang en|uk|ru` симлинкует выбранную локаль в `~/.cursor/commands/` и `~/.cursor/rules/`.  
`tp-state` / `hook` читают `state.config.lang` (fallback: `TP_LANG` env → default как выше).

Маркеры в `questions.md` (любая локаль агента):

| Role | en | uk | ru |
|---|---|---|---|
| Recommendation line | `Recommendation:` | `Рекомендація:` | `Рекомендация:` |
| Answer line | `Answer:` | `Відповідь:` | `Ответ:` |

`applyRecommendedAnswers` / `questionsAllAnswered` матчят любой синоним.

---

## Риски и смягчение

| Риск | Смягчение |
|---|---|
| Агент игнорирует «commit before done» | Rule alwaysApply + явный порядок в § commit; acceptance 11 |
| Два набора commands (корень + lang/) разъедутся | Корень = только symlink/install target; правят только `commands/<lang>/` |
| EN default ломает RU-пользователей | Existing state без lang → `ru`; README migration note |
| Hook update меняет чужие timeout | Update только entries с marker `task-pipeline/hook.sh` |

---

## Definition of done (эпик)

- [ ] Все задачи 01–11 `done` (или явно out с записью в backlog эпика — не в этом scope).
- [ ] `./tests/run.sh` зелёный в CI.
- [ ] `lang=en|uk|ru`: followup и questions auto-unblock работают.
- [ ] Reinstall обновляет hooks; `doctor` ловит рассинхрон имени файла и status.
- [ ] README описывает `--lang` и defaults.
