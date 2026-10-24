# План: 06-i18n-foundation

## Цель

Заложить i18n: `config.lang`, `scripts/i18n.mjs` + `locales/{en,uk,ru}.json`, маркеры questions EN/UK/RU, перенос `commands`/`rules` в `ru/`, install линкует `ru`. Полный перевод команд — 07/08.

## Out of scope

- Полные EN/UK `commands/` и `rules/` (07/08).
- `install.sh --lang` (09).
- Перевод `run-loop.sh` промптов (07).
- Soft `set-config --lang` CLI — достаточно init + ручной edit / TP_LANG.

## Шаги

1. Создать `scripts/i18n.mjs` (`resolveLang`, `loadLocale`, `t`) и `scripts/locales/{en,uk,ru}.json` (fail/followup/notice; RU = текущие строки; EN/UK — нормальные короткие тексты).
2. `tp-state.mjs`: lang при init (new→en|TP_LANG; merge без lang→ru); `t()` для fail/warn/followup/notice; regex Recommendation/Answer/UK; auto-fill той же меткой языка.
3. `hook.mjs`: notice «агент задал вопрос» через `t` (lang из state через hook-followup result или TP_LANG).
4. `mkdir commands/ru rules/ru` + move файлов; `install.sh` → `commands/ru`, `rules/ru`.
5. Тесты: new init lang=en; old без lang → ru после re-init; questions `Recommendation`/`Answer` unblock; `./tests/run.sh`.
6. how-it-works + CONTRIBUTING: lang defaults, layout `commands/<lang>`.

## DoD

- [ ] New init пишет `lang` (default en).
- [ ] Old state без lang → ru при merge init.
- [ ] EN markers questions разблокируют.
- [ ] install → ru/; tests green; i18n shared.

## Как проверить

```bash
./tests/run.sh
node --check scripts/i18n.mjs scripts/tp-state.mjs scripts/hook.mjs
```
