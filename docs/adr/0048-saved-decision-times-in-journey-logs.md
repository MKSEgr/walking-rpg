# ADR 0048: saved decision times in journey logs

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #363](https://github.com/MKSEgr/walking-rpg/issues/363)

## Контекст

Current decision log и раскрываемая history недавних походов уже содержат
immutable `resolvedAt` для каждого решения, но показывают только событие,
выбор, исход и награды. Completion time связывает с прогулкой весь поход, но
не помогает различить отдельные шаги длинной последовательности.

Новый server timestamp не нужен: каждая persisted resolution уже переносит
authoritative instant. Client clock, cache metadata, время Home-response или
вычисленная длительность не имеют той же бизнес-семантики.

## Решение

1. Current `decisionLog` и раскрытая recent archive history используют только
   `decision.resolvedAt` соответствующей immutable записи.
2. Mobile сохраняет instant неизменным в domain model, а на presentation
   boundary переводит его в локальную timezone устройства.
3. Дата и время форматируются через Material localizations выбранной RU/EN
   locale; видимый label и accessibility summary переиспользуют одну строку.
4. Presentation не выводит вычисленную длительность и не обращается к current
   content, client clock, cache metadata или времени Home-response.
5. Существующая fail-closed ISO-8601 validation остаётся границей malformed
   данных; backend, API shape, schema и persisted history не меняются.

## Последствия

- игрок видит локальное время каждого принятого решения в текущей и недавней
  сохранённой истории;
- смена locale/timezone меняет только presentation, а не immutable факт;
- видимый текст и screen-reader summary не расходятся;
- database migration, изменение API shape, rewards, topology и archive limit
  не требуются;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Удалить decision-time label, localization messages, tests и документацию.
Backend, database, cached snapshot shape и persisted history не требуют
rollback или migration.
