# ADR 0067: authoritative companion evolution guidance

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #401](https://github.com/MKSEgr/walking-rpg/issues/401)

## Контекст

Platform уже возвращает для каждого спутника текущую связь, server-authored
порог следующей эволюции, текущую стадию и максимальную стадию. Mobile
показывал `current / target` и состояние готовности, но игроку приходилось
самому вычислять остаток. Для финальной формы следующий порог неприменим.

## Решение

1. Accepted `PlatformPet` остаётся источником текущей связи, порога и стадий;
   mobile не хранит собственную таблицу evolution thresholds.
2. Presentation-модель вычисляет non-negative remaining как `target - current`
   только для growing state. Ready-to-evolve и fully evolved возвращают `0`;
   финальная форма не получает fake target.
3. Journal показывает для growing companion одну точную RU/EN строку с
   remaining bond. Существующая ready/final guidance не меняется.
4. `CompanionBondSignal` получает уже вычисленный remaining из owning model и
   включает его в единую exact semantics. Повторяющая visual line исключается
   из semantics, чтобы значение объявлялось ровно один раз.
5. Backend, Platform API/schema, persistence, thresholds, evolution command,
   rewards и economy не меняются.

## Последствия

- близость следующей формы понятна без ручного вычитания;
- mobile остаётся presentation consumer server-authored evolution target;
- ready и final states не получают ложного остатка или следующей цели;
- assistive technologies получают точное значение без duplicate announcement;
- compact large-text layout использует существующую вертикальную reflow-модель.

## Откат

Удалить derived getter, RU/EN remaining copy, дополнительный semantics argument,
coverage и documentation additions. API, persisted data и migrations не
затрагиваются.
