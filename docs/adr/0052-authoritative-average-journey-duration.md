# ADR 0052: authoritative average journey duration

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #371](https://github.com/MKSEgr/walking-rpg/issues/371)

## Контекст

Lifetime-летопись показывает total и longest duration завершённых походов, но
не объясняет среднюю длительность одного подтверждённого маршрута. Деление в
Flutter создало бы отдельную семантику округления и могло бы использовать
неполный recent archive вместо полной authoritative history.

## Решение

1. Backend публикует additive nullable non-negative
   `journeyChronicle.averageDurationSeconds`.
2. Service вычисляет average после объединения historical totals и current
   authoritative `COMPLETED` как целочисленное floor-деление
   `totalDurationSeconds / completedJourneyCount`.
3. Historical total уже использует полную receipt-proven history: journey 1
   начинается в initial cycle/progress creation, journey 2+ — в exact
   journey-start receipt, а final — последняя immutable resolution exact
   journey. Recent archive в расчёте не участвует.
4. Если total опущен из-за missing/reversed boundary, average также опускается.
   Partial/recent fallback, client clock, cache/Home-response time и current
   content не используются.
5. Mobile принимает legacy omission и fail-closed требует, чтобы supplied
   average был non-negative, имел total и точно совпадал с тем же floor-result.
   RU/EN chip входит в полную accessibility summary.

## Последствия

- rounding определяется backend-контрактом, а не отдельными клиентами;
- average охватывает всю подтверждённую историю и current completion ровно
  один раз;
- total, longest и average используют общий duration formatter и omission
  boundary;
- schema migration, rewards/economy, progression, topology, archive limit и
  external validation gates не меняются.

## Откат

Удалить `averageDurationSeconds` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
