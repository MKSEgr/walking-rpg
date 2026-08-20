# ADR 0047: journey recap completion time

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #361](https://github.com/MKSEgr/walking-rpg/issues/361)

## Контекст

Current `completionRecap` и recent archive уже переносят persisted
`finalDecision.resolvedAt`, но Путевой журнал не показывает время завершения.
Номер похода, финал и награды позволяют вспомнить содержание маршрута, однако
несколько похожих итогов трудно связать с конкретной прогулкой.

Вводить новый server timestamp не требуется: terminal immutable resolution
уже является authoritative фактом завершения. Client clock, cache timestamp
или время чтения Home не имеют той же бизнес-семантики и могут сдвигаться
независимо от сохранённого решения.

## Решение

1. Current и recent recap используют только `finalDecision.resolvedAt` как
   completion moment.
2. Mobile сохраняет instant неизменным в domain model, а на presentation
   boundary переводит его в локальную timezone устройства.
3. Дата и время форматируются через Material localizations выбранной RU/EN
   locale; видимый label и accessibility summary переиспользуют одну строку.
4. Legacy recap без `finalDecision` не получает placeholder или вычисленное
   client-side время.
5. Существующая fail-closed ISO-8601 validation остаётся границей malformed
   данных; backend/API/schema и persisted history не меняются.

## Последствия

- текущий итог и недавний архив можно связать с локальным временем прогулки;
- смена locale/timezone меняет только presentation, а не сохранённый факт;
- offline cache показывает тот же persisted instant в текущих локальных
  настройках без подмены временем cache;
- database migration, изменение API shape, наград, topology и archive limit не
  требуются;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Удалить completion label, localization messages, tests и документацию.
Backend, database, cached snapshot shape и persisted history не требуют
rollback или migration.
