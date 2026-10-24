# Check-report: 03-commit-before-done

## Раунд 1

### Вердикт

Контракт commit-before-done зафиксирован в §8 команды, отдельном always-on rule и how-it-works; rollback через `--force` описан. Soft-check в tp-state пропущен по Q1. `install.sh` подхватывает новый `.mdc` через glob. `./tests/run.sh` зелёный. Findings нет.

### Покрытие плана

| DoD | Статус |
|---|---|
| §8 + rule: порядок и rollback | сделано |
| install ставит rule (glob) | сделано |
| Нет противоречий с no-stop / autonomous-checks | сделано |
| how-it-works | сделано |
| `./tests/run.sh` | сделано |

### Findings

нет

### Открытые вопросы

нет
