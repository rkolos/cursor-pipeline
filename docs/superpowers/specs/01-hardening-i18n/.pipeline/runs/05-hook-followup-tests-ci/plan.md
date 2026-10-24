# План: 05-hook-followup-tests-ci

## Цель

Покрыть ветки `tp-state hook-followup` shell-тестами с изолированным `HOME`, добавить GitHub Actions на `./tests/run.sh`, кратко отметить CI в README. Тест `hook.mjs stop` — out of scope (хрупкий payload).

## Out of scope

- E2E `hook.mjs stop` с fake Cursor session (спека: optional / хрупко).
- i18n строк followup (06+).
- Badge в README (optional) — только строка про CI.

## Шаги

1. **`tests/run.sh`**: в начале `TEST_HOME=$(mktemp -d); export HOME="$TEST_HOME"; trap cleanup` — все дочерние тесты пишут active/sessions только в temp.
2. **`tests/hook-followup.test.sh`**: сценарии через init/set + `hook-followup --workspace`:
   - in-progress/implement → followup, нет `kind`
   - awaiting-approval → notice, нет followup
   - blocked без ответов → notice questions.md
   - blocked + Рекомендация → followup resume
   - done + next todo + continueNextTask true → `kind: next-task`
   - continueNextTask false → notice, нет kind next-task / нет followup next
3. **`tests/run.sh`**: вызвать новый тест.
4. **`.github/workflows/test.yml`**: push/PR, ubuntu-latest, Node 20, `./tests/run.sh`.
5. **`README.md`**: строка про CI / `./tests/run.sh` in Actions.

## DoD

- [ ] Все ветки hook-followup из спеки с assert.
- [ ] CI workflow есть и гоняет `./tests/run.sh`.
- [ ] `./tests/run.sh` зелёный с temp HOME.

## Как проверить

```bash
./tests/run.sh
```

## Edge cases

| Кейс | Поведение |
|---|---|
| Нет active для workspace | hook-followup молчит (stdout пустой) — не обязательно в DoD |
| Рекомендация автозаполняет Ответ | followup resume |
