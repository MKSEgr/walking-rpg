# ADR 0086: authoritative current-journey decision count

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #442](https://github.com/MKSEgr/walking-rpg/issues/442)

## Контекст

Platform journal уже показывает accepted `decisionLog` только текущего похода.
Каждая доступная скринридеру запись сообщает свой index и total, но sighted
игроку приходится вручную считать карточки, чтобы оценить длину истории.

## Решение

1. Mobile считает принятыми ровно элементы accepted `decisionLog`.
2. Count показывается существующей RU/EN строкой только для непустого журнала.
3. Mobile не соединяет журнал с `routeTrail`, не выводит event completion и не
   пересчитывает rewards, route state или decision ordering.
4. Видимая count-строка исключается из semantics: каждая decision entry уже
   объявляет свой index и total, а empty state имеет отдельную подсказку.
5. Home API, backend, persistence и event resolution не меняются.

## Последствия

- длина принятой истории текущего похода видна без ручного подсчёта;
- legacy/empty snapshots сохраняют прежнее спокойное состояние;
- server-owned ordering и immutable decision copy остаются без изменений.

## Откат

Удалить derived count, presentation, tests и documentation. Wire contract и
persisted data не затрагиваются.
