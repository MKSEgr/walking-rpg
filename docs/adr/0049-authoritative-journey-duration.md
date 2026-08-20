# ADR 0049: authoritative journey duration

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #365](https://github.com/MKSEgr/walking-rpg/issues/365)

## Контекст

Current и recent journey recap уже показывают immutable completion
moment, но не объясняют длительность похода. Client clock, время
Home-response, cache metadata и current content не являются authoritative
источниками старта. Публикация обоих timestamp расширила бы API сильнее,
чем нужно для игрового итога.

## Решение

1. Backend публикует additive nullable `durationSeconds` в current
   `completionRecap` и каждом `recentJourneyRecaps[]`.
2. Duration — целые неотрицательные секунды между persisted start
   exact journey и `finalDecision.resolvedAt`.
3. Journey 1 использует initial `expedition_journey_cycle.created_at`
   с fallback на `expedition_progress.created_at`; journey 2+ использует
   `processed_expedition_journey_start.server_time` exact `journeyNumber`.
4. Missing start/final или start позже final дают omission. Backend не
   выводит approximate duration из первого decision, response/cache time
   или current content.
5. Mobile принимает legacy omission, fail-closed отклоняет
   malformed/negative duration и duration без final decision. RU/EN visible
   label и accessibility summary переиспользуют одну строку.

## Последствия

- current и recent recap объясняют длительность exact journey одинаково;
- API не раскрывает отдельный start timestamp;
- legacy и неполная historical data остаются читаемыми без
  выдуманного значения;
- schema migration, rewards/economy, progression, topology, archive limit и
  external validation gates не меняются.

## Откат

Удалить `durationSeconds` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
