# Spec 01 — Task 09 — `install.sh --lang` + documentation

**Parent plan:** [00-plan.done.md](00-plan.done.md) · очередь **09** · priority **P1**  
**Depends on:** [06](06-i18n-foundation.done.md), [07](07-locale-english.done.md), [08](08-locale-ukrainian.done.md)

## Description

1. `install.sh`:
   - `./install.sh [--lang en|uk|ru]` (default **`en`**).
   - Env override: `TP_LANG`.
   - Symlink `~/.cursor/commands/{task-pipeline,tp-fact,tp-check}.md` ← `commands/<lang>/…`
   - Symlink `~/.cursor/rules/task-pipeline-*.mdc` ← `rules/<lang>/…`
   - Persist last install lang in `~/.cursor/task-pipeline/install.json` `{ "lang": "en" }` для повторного install без флага.
   - Uninstall — без изменений по очистке; lang file можно оставить.
2. Документация (EN):
   - `README.md` — Language section: agent surfaces en/uk/ru; docs EN; defaults (new init `en`, legacy state `ru`); `--lang`; `config.lang` / `TP_LANG`.
   - `docs/how-it-works.md` — lang resolution, questions markers table.
   - `CONTRIBUTING.md` — как править три локали (менять все `commands/<lang>/` при смысловом изменении).
3. `run-loop.sh`: уважать lang из state при формировании PROMPT (ссылка на ту же `~/.cursor/commands/task-pipeline.md` — достаточно; строки notify из locale).

## Files

- Modify: `install.sh`, `README.md`, `docs/how-it-works.md`, `CONTRIBUTING.md`, `scripts/run-loop.sh`
- Create: note in README troubleshooting «wrong language»

## Pay attention

- Reinstall with new `--lang` replaces command/rule symlinks (backup as today if replacing non-repo files).
- Не требовать от пользователя копировать tasks на трёх языках — только agent packs.
- Default install `en` не меняет уже существующие `state.config.lang`.

## Definition of done

- [ ] `./install.sh --lang uk` линкует uk packs; повтор без флага берёт `install.json`.
- [ ] README/how-it-works описывают lang defaults и markers.
- [ ] CONTRIBUTING: правило синхронизации трёх локалей.
- [ ] `./tests/run.sh` зелёный.
