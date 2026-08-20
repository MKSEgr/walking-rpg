# ADR 0053: authoritative longest journey identity

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #373](https://github.com/MKSEgr/walking-rpg/issues/373)

## Контекст

Lifetime-летопись показывает `longestDurationSeconds`, но не связывает рекорд
с конкретным походом. Поиск равного duration среди пяти recent recaps неполон,
а без общего tie-break разные клиенты могли бы называть разные journeys.

## Решение

1. Backend публикует additive nullable positive
   `journeyChronicle.longestJourneyNumber` только вместе с longest duration.
2. Repository выбирает record по duration DESC, journey number ASC на той же
   полной receipt-proven history и exact start/final boundaries, что lifetime
   total и longest duration.
3. Service сравнивает current authoritative `COMPLETED` ровно один раз. Current
   journey заменяет historical identity только при строго большей duration;
   tie сохраняет меньший historical number. После next-journey receipt тот же
   поход приходит только из history.
4. Missing/reversed boundary опускает total, longest duration, record identity
   и average. Recent archive, client clock, current content и partial winner не
   используются.
5. Mobile принимает legacy omission и сохраняет generic longest label. Если
   number supplied, он должен быть положительным, входить в completed count и
   иметь longest duration; RU/EN chip и semantics называют journey.

## Последствия

- duration-рекорд имеет стабильную identity по полной подтверждённой history;
- равные records детерминированы и не зависят от SQL/client ordering;
- legacy snapshot без identity остаётся читаемым;
- schema migration, rewards/economy, progression, topology, archive limit и
  external validation gates не меняются.

## Откат

Удалить `longestJourneyNumber` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
