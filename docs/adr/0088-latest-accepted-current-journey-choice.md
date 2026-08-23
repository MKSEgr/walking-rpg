# ADR 0088: latest accepted current-journey choice

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #446](https://github.com/MKSEgr/walking-rpg/issues/446)

## Контекст

Summary последнего accepted решения уже показывает literal event/outcome и
время сохранения, но не показывает `choiceTitle`. Игроку приходится искать
соответствующую запись в полном журнале, чтобы вспомнить собственный выбор.

## Решение

1. Summary использует `choiceTitle` только последнего элемента accepted
   `decisionLog`.
2. RU/EN UI показывает literal choice рядом с event/outcome/save time.
3. Mobile не сопоставляет запись с `routeTrail` или текущим event state, не
   выводит доступность, правильность или последствия выбора.
4. Summary сохраняет одну semantics node; видимые дочерние строки исключены из
   повторного объявления.
5. Home API, backend, persistence, rewards и event resolution не меняются.

## Последствия

- последний принятый выбор виден без поиска записи в полном журнале;
- immutable event/choice/outcome copy и server-owned ordering сохраняются;
- legacy/empty snapshots не получают выдуманного choice state.

## Откат

Удалить choice-строку из summary, localization, tests и documentation.
Wire contract и persisted data не затрагиваются.
