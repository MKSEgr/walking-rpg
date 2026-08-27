# ADR 0103: authoritative current-journey active companion

- **Статус:** Accepted
- **Дата:** 2026-08-27
- **Связанная задача:** [issue #495](https://github.com/MKSEgr/walking-rpg/issues/495)

## Контекст

Home snapshot уже содержит accepted active companion как required `petName` и
additive stable `petId`, но read-only journal текущего похода не связывал этот
fact с записью. Platform snapshot также содержит active pet, а READY
requirements и decision rewards могут называть питомцев, однако эти источники
имеют другую семантику и не должны подменять accepted Home identity.

## Решение

1. Journal читает active companion только из accepted Home `petId/petName`.
2. Exact known `petId` разрешает current mutable name через existing RU/EN
   stable-ID localization resolver.
3. Legacy snapshot без `petId` и unknown future ID сохраняют literal accepted
   `petName` без определения identity по display copy.
4. Platform active pet, route trail, current node, READY event/requirement,
   decision reward и local catalog state не подменяют и не восстанавливают
   Home companion identity.
5. Label получает отдельную visible строку и одну dedicated semantics node,
   пригодную для compact large-text layout.
6. Persisted decision rewards и journey history остаются literal; current
   companion label не переписывает прошлые facts.
7. Home API, backend, persistence, commands, eligibility, rewards и external
   validation не меняются.

## Последствия

- журнал явно показывает выбранного для текущего состояния спутника в RU/EN;
- известный mutable content следует locale, а legacy/future server content
  остаётся читаемым;
- независимые Platform, route, event и reward facts не становятся скрытым
  источником companion identity;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal label, localization keys, tests и этот documentation record.
Accepted Home snapshot contract, Platform hero, companion controls и journey
history останутся без изменений.
