# Check-report: 02-init-infer-status-from-filename

## Раунд 1

### Вердикт

`statusFromFileName` + demotion лишних `in-progress` в `cmdInit` соответствуют плану и DoD. Known id сохраняют phase при re-init; два `.in-work` дают warning и blocked. Тесты и `./tests/run.sh` зелёные. Findings нет.

### Покрытие плана

| DoD | Статус |
|---|---|
| Тест `.in-work` + plain → in-progress + todo | сделано |
| Тест два `.in-work` → in-progress + blocked, exit 0, warning | сделано |
| Known id не затирает status/phase | сделано |
| `./tests/run.sh` + `node --check` | сделано |
| Абзац recovery в how-it-works.md | сделано |

### Findings

нет

### Открытые вопросы

нет
