# ADR 0113: authoritative current-journey READY event scene

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #517](https://github.com/MKSEgr/walking-rpg/issues/517)

## Контекст

Current-journey journal уже показывает accepted READY-event title, summary,
available-choice count и choice details. Home и First Journey одновременно
используют existing `ExpeditionEventScene`, который выбирает reviewed artwork
по exact stable event ID и имеет neutral code-native fallback для future IDs.

Journal не должен выбирать scene из expedition phase, current node, route
trail, ENERGY progress, decisions, Platform event/progression, history или
local catalog: эти соседние facts не подтверждают accepted READY event.
Existing event block уже публикует одну combined semantics node, поэтому
отдельная image semantics создала бы duplicate announcement.

## Решение

1. Journal строит `ExpeditionEventScene` только из accepted Home
   `unlockedEvent` со status exact `READY`.
2. Scene получает exact `eventId` и localized current title из того же event,
   который наполняет visible event copy.
3. Только exact reviewed event ID выбирает existing illustration. Unknown
   future ID сохраняет literal Home title/summary и получает neutral fallback;
   copy не участвует в artwork dispatch.
4. Absent, `RESOLVED` и unknown status fail-closed не создают scene, даже если
   expedition phase или Platform facts выглядят ready-like.
5. Current node, route trail, ENERGY, decisions, Platform event/progression,
   history и catalog не подменяют scene identity или readiness.
6. Scene находится внутри existing event `ExcludeSemantics`; прежняя combined
   semantics node для title, summary и choice facts остаётся единственным
   accessibility announcement.
7. Home API, backend, persistence, commands, choices, rewards, requirements,
   assets, external validation и immutable `alpha-rc1` не меняются.

## Последствия

- current READY event получает существующую reviewed visual identity;
- known mutable copy остаётся localized, future copy — literal и neutral;
- non-READY и cross-surface decoys не создают ложную scene;
- accessibility не получает duplicate image announcement;
- изменение обратимо на mobile presentation уровне.

## Откат

Удалить nested scene, integration coverage и этот record. Existing READY-event
copy/semantics, Home contract, choices и commands останутся без изменений.
