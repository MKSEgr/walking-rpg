# ADR 0112: authoritative current-journey expedition progress signal

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #515](https://github.com/MKSEgr/walking-rpg/issues/515)

## Контекст

Current-journey journal уже показывает accepted Home ENERGY progress как
literal text и generic linear indicator. First Journey одновременно использует
existing `ExpeditionProgressSignal`: он выбирает reviewed route contour только
по exact stable expedition ID, сохраняет neutral fallback для future content и
clamp-ит только декоративный painted trace.

Platform weekly route, route/current-node, READY event, decisions, history и
local catalog содержат соседние progression-like facts, но не являются
источником текущей экспедиции. Existing ENERGY label уже публикует dedicated
semantics node, поэтому новый decorative child не должен создавать второе
announcement.

## Решение

1. Journal строит `ExpeditionProgressSignal` только из accepted Home
   `expeditionId`, `expeditionProgress` и `requiredEnergy`.
2. Только exact `starter-expedition-v1` выбирает reviewed Outer Beacon route
   contour. Unknown future ID получает existing neutral field; display name не
   участвует в art dispatch.
3. Progress и target остаются literal в visible и accessible copy, включая
   over-target значения.
4. Signal clamp-ит только painted trace. Journal не выводит из чисел phase,
   completion, event availability, rewards, remaining energy, spendability или
   command eligibility.
5. Platform weekly route, route/current-node, READY event, decision log,
   history и catalog не подменяют signal identity или progress.
6. Signal остаётся внутри existing ENERGY `ExcludeSemantics`; прежняя outer
   semantics node остаётся единственным accessibility announcement.
7. Generic linear indicator удаляется без изменения Home API, backend,
   persistence, commands, rewards, assets, external validation или immutable
   `alpha-rc1`.

## Последствия

- journal использует существующий expedition-specific visual вместо generic
  progress bar;
- known и future expedition identity остаются fail-closed и различимыми;
- literal authoritative ENERGY copy не меняется из-за visual clamp;
- cross-surface progression decoys не влияют на current journey;
- accessibility не получает duplicate announcement.

## Откат

Вернуть generic linear indicator и удалить nested signal, integration coverage
и этот record. Existing ENERGY copy/semantics и accepted Home contract останутся
без изменений.
