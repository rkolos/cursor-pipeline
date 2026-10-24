# Example `questions.md` (English markers)

Used by the agent under `runs/<taskId>/questions.md` when `lang=en` (or any locale — the parser accepts all synonyms). For Ukrainian labels use `Рекомендація:` / `Відповідь:` (`lang=uk`).

```markdown
## Q1: Which default for new pipeline state?
Context: Public repo vs existing RU installs.
Options: A) en for new init — consequences: public-friendly; B) ru for new init — consequences: breaks EN-first install story.
Recommendation: A
Answer: A
```

Labels the pipeline understands for recommendation/answer lines:

| Role | en | uk | ru |
|------|----|----|-----|
| Recommendation | `Recommendation:` | `Рекомендація:` | `Рекомендация:` |
| Answer | `Answer:` | `Відповідь:` | `Ответ:` |
