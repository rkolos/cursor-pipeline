# Check-report: 09-install-lang-and-docs

## Вердикт

Реализация совпадает с планом и DoD: `--lang` / `TP_LANG` / `install.json` (default `en`), docs (README Language + troubleshooting, how-it-works markers, CONTRIBUTING sync-all-langs), `run-loop` notify через `i18n.mjs`, тест `install-lang.test.sh`. `./tests/run.sh` зелёный. Findings нет.

## DoD

| Критерий | Статус |
|----------|--------|
| `./install.sh --lang uk` + persist без флага | сделано (+ тест) |
| README / how-it-works | сделано |
| CONTRIBUTING sync трёх локалей | сделано |
| `./tests/run.sh` | зелёный |

## Findings

нет
