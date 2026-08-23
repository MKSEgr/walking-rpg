# ADR 0087: latest accepted current-journey decision

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #444](https://github.com/MKSEgr/walking-rpg/issues/444)

## Контекст

Platform journal сохраняет accepted `decisionLog` текущего похода в порядке,
полученном от Home API. При длинном журнале последний сохранённый исход виден
только после прокрутки всех предыдущих записей.

## Решение

1. Mobile проецирует latest decision только как последний элемент accepted
   `decisionLog`.
2. Непустой журнал показывает literal event/outcome и форматирует accepted
   `resolvedAt` рядом с заголовком; empty журнал сохраняет прежнее состояние.
3. Mobile не сортирует журнал по времени, не соединяет его с `routeTrail` или
   текущим event state и не выводит completion из положения записи.
4. Summary имеет одну RU/EN semantics node; видимые дочерние строки исключены
   из повторного объявления.
5. Home API, backend, persistence, rewards и event resolution не меняются.

## Последствия

- последний принятый исход виден без прокрутки полного журнала;
- immutable event/outcome copy и server-owned ordering остаются буквальными;
- legacy/empty snapshots не получают выдуманного latest state.

## Откат

Удалить nullable projection, summary, localization, tests и documentation.
Wire contract и persisted data не затрагиваются.
