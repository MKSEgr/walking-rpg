# ADR 0061: authoritative today status in weekly rhythm

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #389](https://github.com/MKSEgr/walking-rpg/issues/389)

## Контекст

Authoritative trail из ADR 0059 показывает семь последовательных active/rest
дат, а guidance из ADR 0060 объясняет остаток до мягкой цели. Однако игроку
нужно помнить, что endpoint справа является сегодняшним днём. Сравнение с
device clock добавило бы новую timezone/clock boundary и могло бы расходиться с
Home `localDate`; warning-акцент для rest противоречил бы non-punitive canon.

## Решение

1. Mobile считает today только элемент, чей `localDate` совпадает с Home
   `localDate`. Production parser уже fail-closed требует, чтобы такой endpoint
   был последним элементом полного trail.
2. RU/EN line показывает server-owned дату через Material locale formatter и
   называет active day либо neutral rest day.
3. Exact today marker получает тонкую primary outline, но сохраняет свой
   walking/moon glyph, active/rest fill и обычное место в chronological trail.
4. Today-specific copy заменяет generic classification exact endpoint внутри
   единой weekly semantics summary и поэтому объявляется ровно один раз.
5. Legacy weekly object без `days` не получает today copy/highlight. Client
   clock, Health history, notifications, streak и economy не используются.

## Последствия

- игрок видит текущую точку rolling week без знания порядка массива;
- rest today остаётся нормальным состоянием, а outline означает только время;
- Home API и server-authoritative data contract не меняются;
- compact layout получает одну короткую fluid line над существующим trail.

## Откат

Удалить today copy, outline, tests и documentation additions. API, persistence
schema и migration rollback не затрагиваются.
