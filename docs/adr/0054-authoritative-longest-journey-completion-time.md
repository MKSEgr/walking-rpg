# ADR 0054: authoritative longest journey completion time

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #375](https://github.com/MKSEgr/walking-rpg/issues/375)

## Контекст

Lifetime-летопись показывает duration и номер рекордного похода, но не момент,
когда рекорд был установлен. Поиск journey в пяти recent recaps неполон, а
client clock или время Home-response не являются историческими фактами.

## Решение

1. Backend публикует additive nullable ISO-8601 instant
   `journeyChronicle.longestJourneyCompletedAt` только вместе с longest
   duration и valid record journey number.
2. Repository получает timestamp из `resolved_at` той же winner-строки, которая
   выбирается по duration DESC, journey number ASC на полной receipt-proven
   history и exact start/final boundaries.
3. Service сравнивает current authoritative `COMPLETED` ровно один раз. При
   строго большей duration он использует immutable `finalDecision.resolvedAt`;
   tie сохраняет historical identity и timestamp.
4. Missing/reversed included boundary опускает total, longest, average, record
   identity и completion instant без recent/partial fallback.
5. Mobile принимает legacy omission и fail-closed отклоняет malformed,
   timezone-less или unpaired instant. UI переводит UTC instant в timezone
   устройства только для RU/EN presentation и общей semantics.

## Последствия

- личный duration-рекорд связан с доказанным immutable временем завершения;
- timestamp наследует тот же deterministic tie-break, что duration и identity;
- legacy snapshot без нового поля остаётся читаемым;
- schema migration, client clock, rewards/economy, progression, topology,
  archive limit и external validation gates не меняются.

## Откат

Удалить `longestJourneyCompletedAt` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
