# ADR 0021: Server-authoritative first-journey observability

- Status: Accepted
- Date: 2026-07-29

## Context

Guided first journey подтверждает реальные действия игрока, но существующая
analytics projection показывала только общий факт завершения onboarding. Она не
могла надёжно ответить, сколько времени прошло от начала маршрута до первого
activity sync, ENERGY, выбора питомца, узла и события. Обычные client telemetry
events для этих переходов недостаточны: они могут потеряться, повториться после
restart или быть отправлены раньше commit основной игровой транзакции.

Legacy state также не содержит точного времени каждого шага. Смешивание
приблизительно восстановленных данных с новыми точными наблюдениями исказило бы
p50/p90 в alpha cohort.

## Decision

- PostgreSQL V9 добавляет `first_journey_milestone` с одной строкой на
  `(user_id, milestone)`.
- Канонический набор:
  `JOURNEY_STARTED`, `FIRST_ACTIVITY_SYNC`, `FIRST_ENERGY`, `PET_SELECTED`,
  `FIRST_NODE_REACHED`, `FIRST_EVENT_RESOLVED`, `ONBOARDING_COMPLETED`.
- Milestones создаются `AFTER INSERT` triggers на уже авторитетных
  `processed_*` и ledger tables. Поэтому запись входит в ту же транзакцию, что
  и игровое действие, и откатывается вместе с ним.
- `ONBOARDING_COMPLETED` записывается только если существуют все шесть
  предшествующих фактов, включая ENERGY из activity ledger. Одних служебных
  onboarding-команд недостаточно. Проверка повторяется после каждого нового
  authoritative факта, поэтому отложенный sync/node/event завершает уже
  сохранённый onboarding без повторной клиентской команды. Отдельный
  transaction-scoped advisory lock сериализует эту сверку по `user_id`, чтобы
  параллельные последние факты не пропустили друг друга.
- Первое значение неизменно: `ON CONFLICT DO NOTHING` сохраняет исходное время
  при exact replay, повторном запуске и последующих событиях.
- V9 восстанавливает доступные legacy milestones с
  `source = BACKFILLED`. Новые записи имеют `source = AUTHORITATIVE`.
- `GET /api/v1/admin/platform/analytics/first-journey` строит cohort-filtered
  read model. Conversion counts включают backfill, но p50/p90 рассчитываются
  только когда и старт, и целевой milestone имеют authoritative source и
  неотрицательный интервал. Все связанные запросы одного ответа выполняются в
  одной `REPEATABLE_READ` snapshot.
- Milestone attributes содержат только минимальные игровые идентификаторы и
  размер ENERGY-награды; raw health samples и cumulative health total не
  копируются.
- Milestones входят в account JSON export и удаляются каскадно вместе с
  `app_user`.

## Consequences

- Alpha может измерять time-to-first-sync, time-to-first-ENERGY,
  time-to-first-node/event и completion без зависимости от best-effort mobile
  telemetry.
- Retention cleanup идемпотентных activity receipts не стирает первый
  подтверждённый факт.
- Старые пользователи участвуют в conversion counts, но явно видны как
  backfilled и не искажают latency percentiles.
- Read model не заменяет физическую device validation или качественную оценку
  permission UX и эмоциональной ценности питомца.

Durable delivery результата, добавленная позже, расширяет эту модель отдельным
ACK milestone без изменения исторического смысла `ONBOARDING_COMPLETED`.
См. [ADR 0023](0023-acknowledged-first-journey-result.md).
