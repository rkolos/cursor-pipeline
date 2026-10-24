# План: 10-tp-state-doctor

## Цель

Команда `tp-state doctor [--dir D] [--fix]`: отчёт о рассинхроне state/файлов и осторожный авторемонт.

## Out of scope

- Удаление orphan runs; автозаполнение Answer; git commit; acceptance smoke (11).

## Шаги

1. `parseArgs`: `--fix` как boolean (рядом с `--force`).
2. `cmdDoctor`: collect problems → optional fix → print JSON; exit 0 если problems пуст после fix.
3. Locale keys для сообщений; `fail.usage` + doctor.
4. Тесты mismatch + `--fix`; README State CLI; how-it-works абзац.

## DoD

- [x] doctor список проблем
- [x] doctor --fix чинит file↔status и multi in-progress
- [x] README
- [x] tests green
