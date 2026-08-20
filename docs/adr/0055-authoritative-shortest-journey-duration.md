# ADR 0055: authoritative shortest journey duration

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #377](https://github.com/MKSEgr/walking-rpg/issues/377)

## Контекст

Lifetime-летопись показывает total, average и longest duration, но не нижнюю
границу завершённых походов. Пять recent recaps не доказывают minimum полной
истории, а client clock и current content не являются историческими фактами.

## Решение

1. Backend публикует additive nullable non-negative
   `journeyChronicle.shortestDurationSeconds` только вместе с lifetime total.
2. Repository вычисляет minimum на полной receipt-proven history по тем же
   exact start/final boundaries, что total, average и longest.
3. Service сравнивает current authoritative `COMPLETED` ровно один раз. При
   меньшей duration он заменяет minimum; после next journey-start receipt тот
   же поход уже учитывается только historical SQL.
4. Missing/reversed boundary любого included journey опускает total, shortest,
   longest, average, record identity и timestamp без recent/partial fallback.
5. Mobile принимает legacy omission и fail-closed отклоняет malformed,
   negative, unpaired или выходящее за supplied average/longest значение.
   RU/EN UI и общая semantics используют существующий duration formatter.

## Последствия

- диапазон lifetime duration основан на единой authoritative boundary;
- minimum не зависит от archive limit или текущей topology;
- legacy snapshot без нового поля остаётся читаемым;
- schema migration, rewards/economy, progression, topology и external
  validation gates не меняются.

## Откат

Удалить `shortestDurationSeconds` из Home projection, mobile model/UI,
localizations, tests и документации. Persisted tables и migration rollback не
требуются.
