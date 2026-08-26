# ADR 0099: authoritative current-journey READY choice descriptions

- **Статус:** Accepted
- **Дата:** 2026-08-26
- **Связанная задача:** [issue #487](https://github.com/MKSEgr/walking-rpg/issues/487)

## Контекст

Journal показывает accepted title доступных READY choices, но одного названия
недостаточно, чтобы вспомнить смысл ожидающего решения. Description уже
приходит в том же authoritative `unlockedEvent` choice и локализуется на Home
по exact event/choice identity. Восстановление описания из topology, rewards,
requirements или consequences создало бы второй client-owned источник.

## Решение

1. Description читается только из `unlockedEvent` со status exact `READY`.
2. Каждое описание принадлежит тому же accepted choice с
   `availability=AVAILABLE`, что и visible title. Server ordering сохраняется,
   locked choices исключаются, requirements не проверяются повторно.
3. Known mutable description локализуется по exact `eventId/choiceId` через
   существующий resolver. Unknown future ID сохраняет literal server fallback.
4. Legacy/empty, locked-only, absent, `RESOLVED` и unknown status не создают
   description rows.
5. Event title, summary, count и каждая пара choice title/description входят в
   одну semantics node в том же порядке.
6. Journal остаётся read-only и не показывает rewards, requirements,
   correctness или consequences. Home остаётся command surface.
7. Phase, node, progress, route trail, decision log, topology и catalog rules
   не выбирают, не сортируют и не восстанавливают descriptions.

## Последствия

- журнал объясняет содержание ожидающих вариантов без дублирования actions;
- pairing, ordering и eligibility остаются server-owned;
- known current content следует RU/EN locale, future copy остаётся читаемой при
  несовпадении версий клиента и сервера;
- reward и gating details не превращаются в client inference.

## Откат

Удалить read-only description rows, localization label, tests и documentation.
Existing READY event title/summary/count/choice titles, Home actions, backend
contract, persistence и commands останутся без изменений.
