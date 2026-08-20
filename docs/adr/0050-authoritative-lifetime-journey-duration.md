# ADR 0050: authoritative lifetime journey duration

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #367](https://github.com/MKSEgr/walking-rpg/issues/367)

## Контекст

Current и recent journey recap показывают authoritative duration exact
journey, но lifetime `journeyChronicle` не объясняет общее время всех
завершённых походов. Сумма пяти recent recaps неполна, а client clock,
Home-response и cache metadata не являются authoritative источниками.

## Решение

1. Backend публикует additive nullable non-negative
   `journeyChronicle.totalDurationSeconds`.
2. Repository суммирует полные целые секунды всех receipt-proven завершённых
   походов без recent limit. Journey 1 использует initial cycle creation с
   fallback на progress creation; journey 2+ — exact journey-start receipt
   `server_time`; final — последняя immutable resolution exact journey.
3. Service добавляет duration current authoritative `COMPLETED` ровно один
   раз. После старта следующего journey тот же итог приходит из historical
   SQL и больше не добавляется как current.
4. Missing start/final или start позже final хотя бы одного included journey
   опускают всё поле. Partial total, recent archive, client clock,
   cache/Home-response time и current content не используются.
5. Mobile принимает legacy omission, fail-closed отклоняет malformed/negative
   value и показывает RU/EN lifetime chip в полной accessibility summary.

## Последствия

- летопись отражает duration всей подтверждённой history, а не видимого
  archive window;
- неполная legacy history не превращается в правдоподобный частичный итог;
- формат current, archived и lifetime duration остаётся единым;
- schema migration, rewards/economy, progression, topology, archive limit и
  external validation gates не меняются.

## Откат

Удалить `totalDurationSeconds` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
