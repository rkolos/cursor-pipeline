# Fact-report: 02-init-infer-status-from-filename

## Вердикт

План совпадает с текущим `cmdInit` (новые id: только `.done`→done, иначе todo; `.in-work` игнорируется) и со спекой. `known` уже мержится через `{ ...existing, file }`. Demotion множественных in-progress и helper `statusFromFileName` — новые. Блокирующих вопросов нет.

## Что исправлено

- **факт:** зафиксировано, что рассинхрон known-todo + файл `.in-work` намеренно out of scope (doctor 10); init не переименовывает и не «чинит» known.
- **edge:** demoted blocked с `phase=null` → `plan` (инвариант blocked из 01).
- **DoD:** повторный init проверяет сохранение phase (`fact`), не только status.

## Вопросы

нет
