# Prompt: следующая задача → Draft PR

Этот prompt запускает ровно один рабочий цикл. На GitHub merge request для
этого проекта называется pull request (PR).

Скопируйте блок целиком в новый запрос:

```text
Продолжи работу над https://github.com/MKSEgr/walking-rpg, используя полный
доступ GitHub-плагина. Выполни ровно один цикл «следующая готовая задача →
полностью проверенный Draft PR». Не изменяй master напрямую и не начинай вторую
задачу до merge первой.

Источники истины:
- docs/VALIDATION_BACKLOG.md — порядок, зависимости и статусная модель;
- docs/PROJECT_ASSESSMENT_2026-08-07.md — стратегия, эпики и gates;
- тело связанного GitHub Issue — scope, acceptance и evidence конкретной задачи;
- docs/NEXT_TASK_TO_PR_PROMPT.md — этот execution contract.

Алгоритм:

1. Синхронизируй состояние.
   - Получи exact SHA актуального master, открытые PR и open task issues.
   - Если уже есть открытый PR для TASK-NNN, не выбирай новую задачу: продолжи
     этот PR, обработай review/CI и доведи его до green + merge-ready.
   - Если предыдущий task PR уже merged, проверь, что намеренная отдельная
     строка `Closes #N` закрыла issue.
     Если автозакрытие не сработало, закрой issue только со ссылкой на merged PR.
   - Статус задачи определяется GitHub Issue: open = не выполнена, closed после
     merge/evidence = выполнена. Не отмечай задачу выполненной до merge.

2. Выбери одну следующую задачу.
   - Прочитай docs/VALIDATION_BACKLOG.md и полное тело issues-кандидатов.
   - Выбери open issue с наименьшим TASK-NNN, для которого все dependencies
     закрыты и нет активного PR.
   - Если задача требует отсутствующего owner decision, credential, account,
     устройства или реального evidence, не выдумывай данные и не открывай
     пустой PR. Зафиксируй точный blocker/required action и выбери следующую
     независимую готовую задачу. Если готовых задач нет — остановись и сообщи
     минимальный набор действий владельца.
   - Не создавай E6/E8/E9 backlog раньше gates, заданных в validation backlog.

3. Зафиксируй scope и изоляцию.
   - Начни отдельную ветку `agent/task-nnn-short-slug` от exact fresh master.
   - Проверь filenames всех открытых PR и не пересекайся с параллельной
     backend/design/infrastructure работой без необходимости outcome-а.
   - Одна task issue = один логический PR. Не добавляй побочные улучшения.
   - Если master сдвинулся до публикации, повторно проверь dependencies и
     пересечения; безопасно перенеси работу на свежую базу либо остановись при
     конфликте.

4. Выполни задачу до acceptance.
   - Следуй Scope / Out of scope / Acceptance / Evidence / Stop и Rollback из
     issue.
   - Сохраняй server-authoritative границы, idempotency, owner isolation и
     fail-closed production configuration.
   - Для manual/device/store/research задач используй только фактически
     полученное redacted evidence. CODE_COMPLETE не заменяет VALIDATED.
   - Никогда не помещай в Git, issue, PR или logs credentials, tokens, signing
     material, verification documents, raw health/identity data или PII.
   - Каждый найденный дефект вынеси в отдельный issue; release blocker должен
     быть исправлен и affected scenario повторно проверен.

5. Проверь результат.
   - Выполни максимальный релевантный набор штатных project/release contracts,
     format/analyze/tests/build или evidence validation.
   - Просмотри полный diff и убедись, что он содержит только заявленный scope.
   - Не объявляй ручной/external gate пройденным по результатам CI.

6. Создай Draft PR.
   - Заголовок начинается с `[TASK-NNN]` и описывает outcome.
   - Body содержит: What, Why, scope/out-of-scope, impact, checks, evidence,
     blockers/rollback и отдельную строку `Closes #<issue>` только для issue,
     acceptance которой полностью выполнен этим PR.
   - Для незавершающих связей используй `Relates to #N` или `Keeps #N open`.
     Никогда не ставь GitHub closing keyword перед external-gate reference даже
     в отрицании: GitHub может закрыть issue при merge.
   - Используй отдельную ветку; master и чужие ветки не изменяй.
   - Дождись всех exact-head CI/release workflows. Исправляй только реальные
     ошибки этого PR и повторяй проверки до green.
   - Сверь Draft/mergeable, exact head SHA, changed filenames, review threads и
     отсутствие нового конфликтующего PR.
   - Оставь PR Draft и не merge без отдельного явного указания владельца.

7. Заверши один цикл.
   - Сообщи: TASK/issue, branch, Draft PR, exact head, changed paths, проверки,
     evidence и оставшиеся внешние blockers.
   - Не бери следующую задачу в этом же цикле. После ручного merge следующий
     запуск этого prompt сначала отметит закрытие issue, затем выберет новую
     готовую задачу.

Если GitHub CLI отсутствует, это не блокер: используй доступные операции
GitHub-плагина для blob/tree/commit/ref/PR. Не проси устанавливать `gh`, если
плагин покрывает требуемую операцию.
```

## Инварианты цикла

- Ровно один task PR одновременно.
- `master` изменяется только через merge владельцем проекта.
- Каноническая отдельная строка `Closes #…` связывает merge только с полностью
  выполненным acceptance; безопасные non-completing связи описаны в
  [PR metadata policy](PR_METADATA_POLICY.md).
- External blocker не превращается в фиктивный документ или pass.
- Следующая волна определяется evidence предыдущего gate, а не желанием
  продолжить feature development.
