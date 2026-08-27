# ADR 0102: authoritative current-journey expedition identity

- **Статус:** Accepted
- **Дата:** 2026-08-27
- **Связанная задача:** [issue #493](https://github.com/MKSEgr/walking-rpg/issues/493)

## Контекст

Home snapshot уже содержит required stable `expeditionId` и accepted mutable
`expeditionName`, но read-only journal текущего похода не показывал, к какой
экспедиции относится запись. Восстановление имени из route trail, current node,
READY event или локального catalog state могло бы связать независимые facts и
показать неверную identity для future content или сохранённого snapshot.

## Решение

1. Journal читает expedition identity только из accepted
   `expeditionId/expeditionName` того же Home snapshot.
2. Exact `starter-expedition-v1` разрешает current mutable name через existing
   RU/EN stable-ID localization resolver.
3. Unknown future ID сохраняет literal accepted `expeditionName` без попытки
   определить identity по display copy.
4. Route trail, current node, READY event, decision log и local catalog state
   не подменяют и не восстанавливают expedition identity.
5. Label получает отдельную visible строку и одну dedicated semantics node,
   пригодную для compact large-text layout.
6. Persisted journey history остаётся literal; новая current label не
   переписывает прошлые decisions, outcomes или recaps.
7. Home API, backend, persistence, commands, eligibility и external validation
   не меняются.

## Последствия

- журнал явно называет экспедицию текущего похода в RU/EN;
- known mutable content следует locale, а future server content остаётся
  читаемым при несовпадении версий;
- независимые route/event facts не становятся неявным источником identity;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal label, localization keys, tests и этот documentation record.
Accepted Home snapshot contract и все существующие journey projections
останутся без изменений.
