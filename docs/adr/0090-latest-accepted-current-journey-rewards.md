# ADR 0090: latest accepted current-journey rewards

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #450](https://github.com/MKSEgr/walking-rpg/issues/450)

## Контекст

Latest decision summary показывает literal event, choice, outcome и description,
но скрывает persisted rewards этой записи. Игроку приходится искать полную
запись журнала, чтобы увидеть непосредственно полученный результат.

## Решение

1. Summary использует reward fields только последнего элемента accepted
   `decisionLog`.
2. RU/EN UI показывает положительные `pilotExperienceGained`, `petBondGained`
   и присутствующий `materialReward` существующими reward labels.
3. Mobile не агрегирует rewards между решениями, не пересчитывает economy и не
   соединяет запись с текущим state.
4. Summary сохраняет одну semantics node; видимые дочерние строки исключены из
   повторного объявления.
5. Legacy/no-reward entry не получает выдуманной reward строки; Home API,
   backend, persistence и event resolution не меняются.

## Последствия

- persisted rewards последнего решения видны без поиска полной записи;
- server-owned ordering и immutable decision copy сохраняются;
- отсутствие reward fields остаётся корректным legacy/no-reward state.

## Откат

Удалить reward строку из latest card, localization, tests и documentation.
Wire contract, persisted data и полные записи журнала не затрагиваются.
