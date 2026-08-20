# ADR 0051: authoritative longest journey duration

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #369](https://github.com/MKSEgr/walking-rpg/issues/369)

## Контекст

Lifetime `totalDurationSeconds` объясняет суммарное время завершённых походов,
но не показывает личный рекорд игрока. Maximum пяти recent recaps неполон, а
client-side inference создаёт разные правила omission и округления между
версиями mobile.

## Решение

1. Backend публикует additive nullable non-negative
   `journeyChronicle.longestDurationSeconds` только вместе с lifetime total.
2. Repository выбирает maximum полных целых секунд всех receipt-proven
   завершённых походов без recent limit. Journey 1 использует initial cycle
   creation с fallback на progress creation; journey 2+ — exact journey-start
   receipt `server_time`; final — последняя immutable resolution exact journey.
3. Service сравнивает duration current authoritative `COMPLETED` с historical
   maximum ровно один раз. После старта следующего journey тот же duration
   приходит из historical SQL.
4. Missing start/final или start позже final хотя бы одного included journey
   опускают total и longest. Partial/recent maximum, client clock,
   cache/Home-response time и current content не используются.
5. Longest не превышает total. Mobile принимает legacy omission, fail-closed
   отклоняет malformed/negative/inconsistent value и показывает RU/EN record
   chip в полной accessibility summary.

## Последствия

- летопись показывает рекорд полной подтверждённой history, а не archive
  window;
- неполная legacy history не превращается в правдоподобный partial maximum;
- current, archived, total и record durations используют один formatter;
- schema migration, rewards/economy, progression, topology, archive limit и
  external validation gates не меняются.

## Откат

Удалить `longestDurationSeconds` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
