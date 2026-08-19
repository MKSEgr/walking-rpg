# ADR 0040: incremental game localization boundary

- **Статус:** Accepted
- **Дата:** 2026-08-19
- **Связанные задачи:** [issue #339](https://github.com/MKSEgr/walking-rpg/issues/339),
  [issue #341](https://github.com/MKSEgr/walking-rpg/issues/341),
  [issue #343](https://github.com/MKSEgr/walking-rpg/issues/343),
  [issue #345](https://github.com/MKSEgr/walking-rpg/issues/345),
  [issue #347](https://github.com/MKSEgr/walking-rpg/issues/347)

## Контекст

Выбор RU/EN уже обязателен до входа и покрывает регистрацию и guided first
journey, однако после onboarding основной Home, compact/wide navigation и
часть accessibility copy возвращались к hard-coded русским строкам. Простое
переключение locale поэтому не давало непрерывного английского маршрута.

Одновременно backend возвращает current content и immutable historical copy
как player-facing literal text. Переписывать сохранённые решения, receipts и
архивные итоги при смене языка нельзя: это разрушило бы фактическую историю.
Определять identity по локализованному display text тоже нельзя.

## Решение

Milestone 26 выполняется последовательными вертикальными срезами:

1. generated ARB является единственным источником client-authored player copy;
2. первый срез локализует compact/wide navigation и полный UI chrome Home:
   loading/error/offline states, journey actions, feedback, route/activity,
   crew, event rewards, equipment, inventory, crafting, upgrades и связанные
   semantics;
3. динамические числа и диагностические значения передаются только typed ARB
   placeholders;
4. второй срез разрешает по stable ID текущие expedition/node/pilot/pet,
   item/equipment/recipe/upgrade identities через RU/EN catalog. Additive
   `pilotId` допускает legacy omission, а unknown ID возвращает server literal;
5. третий срез разрешает title/summary известных READY events и
   title/description/requirement choices только по exact `eventId + choiceId`;
   неизвестные ID сохраняют server literal fallback, а feedback нового события
   использует тот же event resolver;
6. immutable resolved event copy, selected decisions, outcomes, pending
   results, receipts и recaps всегда остаются фактическим persisted literal;
7. четвёртый срез локализует полный Platform journal и его accessibility-
   сигналы. Current onboarding/skill/quest/achievement/cosmetic/season/
   experiment copy разрешается по stable ID, а known command feedback — по
   command type; unknown content сохраняет server literal fallback;
8. immutable decisions, outcomes, reward names и current/archive recaps внутри
   Platform journal остаются persisted literal history;
9. пятый срез локализует account, locale-specific destructive confirmation,
   recovery journal, activity sync, Validation Center и оставшиеся shared
   boundary/design-system surfaces. Stable error/status categories разрешаются
   в безопасную RU/EN copy, а raw exception/backend diagnostics не выводятся;
10. filenames, receipts, timestamps, evidence wire values и server-owned IDs
    остаются literal facts и не используются для определения locale.

Source-level regression запрещает кириллицу во всех app, presentation и shared
boundary/design-system surfaces и отдельно запрещает raw exception
interpolation. RU/EN widget tests проверяют compact/wide layout, text scale 1.6
и semantics.

## Последствия

- выбранная локаль не обрывается сразу после first journey в основном
  expedition shell;
- русская копия сохраняет прежнее поведение, а English shell не зависит от
  server locale;
- rollout остаётся reviewable и не требует backend/schema migration;
- английский Home больше не зависит от server locale для известных current
  identities и открытого event narrative; неизвестная или историческая copy
  остаётся literal по определённой выше границе;
- английский Platform journal не зависит от server locale для известных
  current catalog identities и командного feedback, но не переписывает
  сохранённую историю маршрута;
- Milestone 26 имеет завершённую code boundary; external store, staged rollout
  и physical-device evidence по-прежнему живут в отдельных gates и не
  выводятся из локализации.

## Откат

Первый срез откатывается возвратом вызовов generated localization к прежним
client literals. Второй — удалением current-content resolver и additive
`pilotId`. Третий — удалением current-event resolver из READY event card и
unlock feedback. Четвёртый — удалением Platform catalog/command resolver и
возвратом journal chrome к прежней copy. Пятый — возвратом remaining boundary
calls к прежним client literals при сохранении typed failure mapping.
Legacy-compatible mobile parser не требует миграции cache. Stable IDs,
receipts, historical copy и `alpha-rc1` при этом не меняются.
