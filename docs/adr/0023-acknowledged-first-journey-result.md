# ADR 0023: Acknowledged first-journey result

- Status: Accepted
- Date: 2026-07-30

## Context

ADR 0021 ввёл server-authoritative milestones первого пути. Его
`ONBOARDING_COMPLETED` означает, что platform onboarding state завершён и
существуют шесть игровых фактов до `FIRST_EVENT_RESOLVED`.

ADR 0022 позже разделил resolution и доставку результата. После server commit
rewards/progression capable mobile показывает durable result card и сохраняет
onboarding marker `first-event`; эти действия не задают взаимный порядок.
Отдельный owner-scoped ACK отправляется только после «Продолжить». Поэтому
пользователь может иметь `FIRST_EVENT_RESOLVED` и `ONBOARDING_COMPLETED`, но
потерять ответ, закрыть приложение или ещё не нажать «Продолжить». Считать
такой путь полностью доставленным завышает alpha conversion и занижает
time-to-value.

При этом менять значение существующего immutable `ONBOARDING_COMPLETED`
нельзя: V9 уже записал authoritative и backfilled history с прежней
семантикой, а `(user_id, milestone)` намеренно сохраняет первое значение.

## Decision

- Flyway V11 добавляет milestone
  `FIRST_EVENT_RESULT_ACKNOWLEDGED`.
- Миграция сначала дренирует writers на `processed_event_resolution`, затем
  берёт DDL lock на `first_journey_milestone`, сохраняя порядок блокировок
  V9/V10 writer → milestone trigger при rolling upgrade.
- Первый successful `acknowledged_at: NULL → timestamp` создаёт его
  `AFTER UPDATE` trigger-ом в той же транзакции, что и ACK receipt.
- Durable row обязан начинаться pending. V11 отклоняет
  `handoffRequired = true` вместе с уже заполненным `acknowledged_at`, поэтому
  mixed/direct writer не может подделать authoritative ACK на INSERT.
- Explicit durable ACK записывается с `source = AUTHORITATIVE` и attributes:
  `receiptId`, `eventId`, `handoffRequired = true`,
  `deliveryMode = DURABLE_ACK`.
- HTTP boundary принимает `receiptId` только как полный UUID `8-4-4-4-12` и
  канонизирует регистр до service; malformed/shortened aliases возвращают
  стабильный validation envelope до receipt lookup.
- V10 legacy auto-ACK не доказывает явный просмотр карточки. Он участвует в
  continuity conversion как `source = BACKFILLED`,
  `deliveryMode = LEGACY_AUTO_ACK`, но не в p50/p90.
- V11 backfill выбирает самый ранний acknowledged receipt пользователя и
  также помечает его `BACKFILLED`. Existing pending receipt не получает
  milestone до реального ACK. State-only legacy user без receipt evidence не
  получает синтетический ACK.
- `acknowledged_at` после первого значения неизменяем. Exact replay не
  выполняет physical update, а direct SQL смена или сброс timestamp
  отклоняется trigger-ом. `handoff_required` также неизменяем после INSERT,
  поэтому ACK update не может одновременно подменить delivery mode.
- `ONBOARDING_COMPLETED` сохраняет решение ADR 0021. Новый ACK stage
  добавляется последним в admin read model.
- `stages` остаётся расширяемым массивом. Consumers находят metric по
  `milestone`, а не по индексу или фиксированной длине.
- `conversionFromStarted` остаётся continuity coverage и допускает
  `BACKFILLED`. Explicit alpha ACK rate возвращается отдельно как
  `authoritativeConversionFromStarted`; ACK timings дополнительно требуют
  `attributes.handoffRequired = true`.

## Consequences

- Alpha различает «результат сохранён», «platform onboarding завершён» и
  «результат действительно подтверждён».
- Lost response/restart больше не считается delivery completion до ACK.
- Legacy users остаются видны в conversion с явным data-quality caveat и не
  искажают latency.
- `ONBOARDING_COMPLETED` и ACK — независимые факты и могут временно иметь
  разные reached counts. Это полезно для диагностики потерянного onboarding
  marker или незавершённой result card; массив stages не следует
  интерпретировать как positional schema.
- Retention event receipts не удаляет первый milestone; account export и
  cascade deletion продолжают работать через существующую projection.

## Проверки

- clean Flyway V1–V11 и V10→V11 upgrade;
- V11 lock order не удерживает milestone DDL lock в ожидании старого
  event-resolution writer;
- legacy acknowledged, durable pending и state-only legacy cases;
- rejection pre-acknowledged durable INSERT;
- explicit, repeated и concurrent ACK с одним неизменяемым milestone;
- canonical uppercase receipt и rejection malformed/shortened UUID до lookup;
- ACK transaction rollback сохраняет pending receipt без `acknowledged_at`
  и milestone;
- cohort conversion и p50/p90 отдельно для authoritative и backfilled data;
- API serialization нового additive stage.
