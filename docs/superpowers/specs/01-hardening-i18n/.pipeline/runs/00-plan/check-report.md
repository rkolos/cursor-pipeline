# Check-report: 00-plan

## Раунд 1

### Вердикт

Kickoff-пакет эпика в целом согласован с репозиторием: точки касания на месте, `01`–`11` имеют Description / Files / DoD, зависимости `06→07/08` и `01–10→11` зафиксированы, продуктового диффа вне `docs/superpowers/` нет, `./tests/run.sh` зелёный. Закрытие `done` + коммит — ещё впереди (фаза commit), это не дефект implement. Критичный дефект в тексте задачи `01`: в таблице допустимых смен `phase` нет happy-path `check → commit`, без чего валидация переходов сломает нормальный конвейер.

### Покрытие плана

| DoD | Статус |
|---|---|
| `plan.md` + `fact-report.md` подтверждают готовность эпика к `01+` | сделано |
| Нет staged/committed диффа вне `docs/superpowers/` | сделано (только untracked `docs/superpowers/`) |
| `00-plan` → `done` / `00-plan.done.md`; `Parent plan` → `.done` | не сделано (ожидается фаза commit + `TP set done`) |
| Коммит со ссылкой на `00-plan`; remote при push | не сделано (ожидается фаза commit) |

### Findings

#### Критичные

1. **Где:** `01-state-transition-validation.md` → Description §5 (допустимые смены `--phase` при `in-progress`)
2. **Что не так:** Цепочка и список исключений описывают `implement → check → fix → check → commit` и отдельно `fix → commit`, но **не** разрешают прямой переход `check → commit`. Это основной путь после `status: clean` / отсутствия findings.
3. **Почему важно:** Если `assertTransition` реализовать буквально по спеке, каждый успешный check→commit в `/task-pipeline` будет fail (exit 1), пока агент не обойдёт через `--force` или лишний `fix`. Ломает hardening P0.
4. **Критерий «исправлено»:** В §5 явно разрешён `check → commit` (рядом с `fix → commit` / повторным `fix → check`). При необходимости уточнено, что `check → fix` обязателен только при findings.

#### Минорные

1. **Где:** `00-plan.in-work.md` → Roadmap строка 02 («восстановление `in-progress`/`blocked`/`done` из суффиксов»)
2. **Что не так:** Эпик обещает infer `blocked` из имени файла; задача `02` корректно пишет, что `.in-work` не отличает `blocked` от `in-progress`, recovery без state даёт только `in-progress`.
3. **Почему важно:** Исполнитель `02` или ревьюер эпика могут спорить со roadmap; расхождение scope.
4. **Критерий «исправлено»:** В roadmap/Goal эпика формулировка без обещания restore `blocked` из суффикса (например: `in-progress`/`done` + plain→`todo`; `blocked` не из имени).

### Открытые вопросы

нет

## Раунд 2

### Вердикт

Findings раунда 1 закрыты: в `01` §5 есть `check → commit` и `check → fix`; roadmap `02` в эпике согласован с задачей (`blocked` из имени не восстанавливается). Эпик по-прежнему готов к `01+`, продуктового диффа вне `docs/superpowers/` нет, `./tests/run.sh` зелёный. Остаётся критичный пробел того же класса, что R1: в допустимых сменах `--phase` нет обратного `commit → fix`, хотя текущий `commands/task-pipeline.md` (§8 п.2 / 2a) требует его при провале проверок на commit. Плюс минорная двусмысленность порядка done/commit в тексте `03`.

### Покрытие плана

| DoD | Статус |
|---|---|
| `plan.md` + `fact-report.md` подтверждают готовность эпика к `01+` | сделано |
| Нет staged/committed диффа вне `docs/superpowers/` | сделано (только untracked `docs/superpowers/`) |
| `00-plan` → `done` / `00-plan.done.md`; `Parent plan` → `.done` | не сделано (фаза commit) |
| Коммит со ссылкой на `00-plan`; remote при push | не сделано (фаза commit) |

### Проверка findings раунда 1

| Finding R1 | Статус |
|---|---|
| `01`: нет `check → commit` | закрыто — в §5 явно `check → commit` и `check → fix` |
| Эпик roadmap `02`: обещание restore `blocked` из суффикса | закрыто — формулировка без restore `blocked` из имени |

### Findings

#### Критичные

1. **Где:** `01-state-transition-validation.md` → Description §5 (допустимые смены `--phase`)
2. **Что не так:** В цепочке и списке исключений нет `commit → fix`. Текущий контракт агента (`commands/task-pipeline.md` §8): при падении проверок на commit → `TP set … --phase fix`.
3. **Почему важно:** Буквальная `assertTransition` по спеке `01` отвергнет штатный откат с commit на fix (нужен `--force` или застревание). Ломает hardening P0 так же, как отсутствовавший `check → commit` в R1.
4. **Критерий «исправлено»:** В §5 явно разрешён `commit → fix` (провал проверок / уход в fix-plan с phase commit). Согласовано с запретом произвольных прыжков (`plan → commit` и т.п. по-прежнему fail).

#### Минорные

1. **Где:** `03-commit-before-done.md` → Description п.2
2. **Что не так:** Сначала описан порядок «stage → git commit → при успехе → `TP set done`», затем «Практичный порядок» с `TP set done` **до** `git commit` + rollback. DoD требует однозначности «нет done до успешного commit без rollback».
3. **Почему важно:** Исполнитель `03` может реализовать commit-then-done и потерять rename в том же коммите (или invent второй commit / amend вопреки тексту).
4. **Критерий «исправлено»:** Один канонический порядок: подготовка → `TP set done` (rename) → `git add` → `git commit`; при падении commit — rollback `--force` в `in-progress`/`commit`. Убрать противоречащую «сначала commit, потом done» формулировку.

### Открытые вопросы

нет
