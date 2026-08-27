# ADR 0101: authoritative current-journey READY choice requirements

- **Статус:** Accepted
- **Дата:** 2026-08-27
- **Связанная задача:** [issue #491](https://github.com/MKSEgr/walking-rpg/issues/491)

## Контекст

Journal уже сохраняет accepted title, description и reward preview доступных
READY choices, но не показывает optional requirement, который пришёл в той же
server-authoritative choice. Восстановление условия из inventory, equipment,
companion state или catalog создало бы второй client-owned eligibility engine.

## Решение

1. Requirement читается только из `unlockedEvent` со status exact `READY`.
2. Requirement принадлежит тому же accepted choice с
   `availability=AVAILABLE`, что и visible title/description/rewards.
   Server ordering сохраняется, locked choices исключаются.
3. Отсутствующий accepted `requirement` не создаёт строку.
4. Accepted `requirement.description` локализуется через existing exact
   event/choice resolver; unknown future identity сохраняет literal fallback.
5. Mobile не интерпретирует `type`, slot/item IDs, minimum levels или current
   player state и не вычисляет satisfaction повторно.
6. Legacy/empty, locked-only, absent, `RESOLVED` и unknown status не создают
   requirement rows.
7. Event title, summary, count и каждая группа
   title/description/optional requirement/rewards входят в одну semantics node
   в server order.
8. Journal остаётся read-only и не показывает locked-choice requirement,
   correctness, consequences или actions. Eligibility и resolution остаются
   на Home/backend.

## Последствия

- журнал сохраняет accepted контекст доступного решения без второго rule engine;
- optionality, pairing, ordering и availability остаются server-owned;
- known current requirement следует RU/EN locale, future copy остаётся
  читаемой при несовпадении версий клиента и сервера;
- requirement не становится доказательством eligibility и не добавляет command
  surface.

## Откат

Удалить read-only requirement rows, localization label, tests и documentation.
Existing READY event title/summary/count/choice title/description/rewards, Home
actions, backend contract, persistence и commands останутся без изменений.
