# ADR 0098: authoritative current-journey READY choice titles

- **Статус:** Accepted
- **Дата:** 2026-08-26
- **Связанная задача:** [issue #485](https://github.com/MKSEgr/walking-rpg/issues/485)

## Контекст

Journal уже показывает authoritative title, summary и число доступных choices
готового события. Однако игроку приходится переходить на Home, чтобы вспомнить,
какие именно решения ожидают. Восстановление названий из topology, catalog
rules или requirements создало бы второй client-owned источник event state.

## Решение

1. Titles читаются только из `unlockedEvent` со status exact `READY`.
2. Используются только choices с accepted `availability=AVAILABLE` в принятом
   server ordering. Locked choices исключаются, requirements не проверяются
   повторно.
3. Known mutable choice title локализуется по exact `eventId/choiceId` через
   существующий resolver. Unknown future ID сохраняет literal server fallback.
4. Legacy/empty, locked-only, absent, `RESOLVED` и unknown status не создают
   список choices.
5. Journal показывает только titles. Description, rewards, requirements,
   correctness и consequences остаются на authoritative Home event surface.
6. Event title, summary, available count и choice titles принадлежат одной
   semantics node. Journal не получает action для выбора.
7. Phase, node, progress, route trail, decision log, topology и catalog rules
   не выбирают, не сортируют и не восстанавливают choices.

## Последствия

- игрок видит содержание ожидающего решения прямо в current-journey journal;
- порядок и eligibility остаются server-owned;
- known current content следует выбранной RU/EN locale, а future content не
  теряется при несовпадении версий клиента и сервера;
- Home остаётся единственной поверхностью выполнения event command.

## Откат

Удалить read-only title list, localization label, tests и documentation.
Existing READY event title/summary/count, Home choice actions, backend contract,
persistence и commands останутся без изменений.
