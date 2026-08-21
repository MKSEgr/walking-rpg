# ADR 0065: daily-goal stability clarification

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #397](https://github.com/MKSEgr/walking-rpg/issues/397)

## Контекст

Adaptive daily goal вычисляется по accepted totals до текущей server-owned
локальной даты: backend запрашивает history с `toExclusive = targetDate`.
Поэтому новые шаги могут войти в будущие окна, но не повышают цель текущей
даты. Home показывает текущую цель и её policy, однако без явного объяснения
игрок может ожидать, что планка будет отодвигаться прямо во время ходьбы.

## Решение

1. Для explicit `DEFAULT` или `ADAPTIVE` policy daily presentation получает
   одну спокойную RU/EN clarification: принятые сегодня шаги не повышают
   сегодняшнюю цель и могут учитываться в будущих личных целях.
2. Copy входит в существующую daily-goal semantics summary ровно один раз, а
   visible child исключается из повторного объявления.
3. Legacy snapshot без policy metadata не получает inferred stability rule.
4. Client не вычисляет goal history window, следующую цель или local date и
   не читает Health history либо optimistic sync state.
5. Goal formula/configuration, Home API, backend и persistence не меняются.

## Последствия

- adaptive goal остаётся понятной и предсказуемой во время текущей прогулки;
- сегодняшняя activity сохраняет смысл для будущей персонализации без обещания
  конкретного следующего значения;
- remaining/reached feedback и weekly rhythm продолжают использовать прежние
  authoritative данные;
- legacy compatibility сохраняется без ложного обещания о неизвестной policy.

## Откат

Удалить stability copy, presentation assertions и documentation additions.
API, persisted data и migration rollback не затрагиваются.
