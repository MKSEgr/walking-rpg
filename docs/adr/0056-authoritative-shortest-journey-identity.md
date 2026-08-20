# ADR 0056: authoritative shortest journey identity

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #379](https://github.com/MKSEgr/walking-rpg/issues/379)

## Контекст

Lifetime-летопись показывает minimum duration полной подтверждённой истории,
но не связывает его с конкретным походом. Пять recent recaps не доказывают
identity глобального minimum, а client-side выбор нарушил бы authoritative
boundary и давал разные результаты при legacy/archive-limit данных.

## Решение

1. Backend публикует additive nullable positive
   `journeyChronicle.shortestJourneyNumber` только вместе с shortest duration.
2. Repository выбирает historical winner на полной receipt-proven history по
   duration ASC, journey number ASC с теми же exact start/final boundaries.
3. Service сравнивает current authoritative `COMPLETED` ровно один раз и
   заменяет shortest duration/identity только при строго меньшей duration.
   Равная duration сохраняет более ранний historical winner.
4. Missing/reversed boundary любого included journey опускает total, shortest,
   shortest identity, longest, average, longest identity и timestamp без
   recent/partial fallback.
5. Mobile принимает legacy omission и fail-closed отклоняет malformed,
   non-positive, out-of-range или unpaired identity. RU/EN UI и общая
   semantics используют существующий duration formatter.

## Последствия

- shortest record детерминирован и связан с полной authoritative history;
- current completed journey учитывается один раз до появления successor
  receipt и не переписывает tie;
- legacy snapshot без identity сохраняет generic shortest label;
- schema migration, rewards/economy, progression, topology и external
  validation gates не меняются.

## Откат

Удалить `shortestJourneyNumber` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
