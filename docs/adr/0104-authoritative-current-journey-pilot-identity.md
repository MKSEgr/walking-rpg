# ADR 0104: authoritative current-journey pilot identity

- **Статус:** Accepted
- **Дата:** 2026-08-27
- **Связанная задача:** [issue #497](https://github.com/MKSEgr/walking-rpg/issues/497)

## Контекст

Home snapshot уже содержит accepted pilot identity как required `pilotName` и
additive stable `pilotId`, но read-only journal текущего похода не связывал этот
fact с записью. Platform hero, route/event copy и journey rewards также могут
называть пилота, однако эти источники имеют другую семантику и не должны
подменять accepted Home identity.

## Решение

1. Journal читает pilot identity только из accepted Home `pilotId/pilotName`.
2. Exact known `pilotId` разрешает current mutable name через existing RU/EN
   stable-ID localization resolver.
3. Legacy snapshot без `pilotId` и unknown future ID сохраняют literal accepted
   `pilotName` без определения identity по display copy.
4. Platform hero, route trail, current node, READY event/requirement, decision
   reward, completion history и local catalog state не подменяют и не
   восстанавливают Home pilot identity.
5. Label получает отдельную visible строку и одну dedicated semantics node,
   пригодную для compact large-text layout.
6. Persisted decision rewards и journey history остаются literal; current pilot
   label не переписывает прошлые facts.
7. Home API, backend, persistence, commands, eligibility, rewards и external
   validation не меняются.

## Последствия

- журнал явно показывает пилота текущего accepted state в RU/EN;
- известный mutable content следует locale, а legacy/future server content
  остаётся читаемым;
- независимые Platform, route, event и reward facts не становятся скрытым
  источником pilot identity;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal label, localization keys, tests и этот documentation record.
Accepted Home snapshot contract, Platform hero и journey history останутся без
изменений.
