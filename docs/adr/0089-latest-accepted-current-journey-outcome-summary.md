# ADR 0089: latest accepted current-journey outcome summary

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #448](https://github.com/MKSEgr/walking-rpg/issues/448)

## Контекст

Latest decision summary показывает literal event, choice и outcome title, но
скрывает persisted `outcomeSummary`. Игроку приходится искать полную запись
журнала, чтобы понять, что именно произошло после принятого выбора.

## Решение

1. Summary использует `outcomeSummary` только последнего элемента accepted
   `decisionLog`.
2. RU/EN UI показывает literal description рядом с event/choice/outcome/time.
3. Mobile не сопоставляет запись с `routeTrail` или текущим event state, не
   интерпретирует последствия и не агрегирует rewards.
4. Summary сохраняет одну semantics node; видимые дочерние строки исключены из
   повторного объявления.
5. Home API, backend, persistence и event resolution не меняются.

## Последствия

- последний persisted результат виден без поиска полной записи журнала;
- immutable decision copy и server-owned ordering сохраняются;
- legacy/empty snapshots не получают выдуманного outcome summary.

## Откат

Удалить outcome-summary строку из latest card, localization, tests и
documentation. Wire contract и persisted data не затрагиваются.
