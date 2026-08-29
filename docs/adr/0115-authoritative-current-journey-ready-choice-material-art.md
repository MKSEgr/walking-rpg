# ADR 0115: authoritative current-journey READY choice material art

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #521](https://github.com/MKSEgr/walking-rpg/issues/521)

## Контекст

Current-journey journal уже показывает accepted available READY-choice signal,
title, description, optional requirement и reward в server order. Optional
material preview остаётся только текстом, хотя Home flow использует existing
`ExpeditionItemEmblem` рядом с тем же choice layout. Компонент выбирает
reviewed asset или code-native art по exact item ID и имеет neutral fallback
для future content.

Journal не должен выбирать material art из item name, quantity, reward copy,
Platform inventory, decision history, route state или local catalog. Material
другого choice также не подтверждает paired preview. Existing event block уже
публикует одну combined semantics node, поэтому отдельная image semantics
создала бы duplicate announcement.

## Решение

1. Journal переносит optional `materialReward.itemId` только из каждой
   accepted `availableChoices` entry accepted Home event со status exact
   `READY`.
2. При наличии preview тот же `EventChoiceSignalLayout` получает trailing
   `ExpeditionItemEmblem`; choice без material не получает placeholder art.
3. Только exact reviewed item ID выбирает existing asset или code-native art.
   Unknown future ID получает neutral fallback; item name, quantity и reward
   copy не участвуют в dispatch.
4. Journal сохраняет accepted server ordering и pairing с title, description,
   optional requirement и reward. Locked, absent, `RESOLVED` и unknown event
   status fail-closed не создают emblem.
5. Platform inventory, route trail, decision history, event phase и catalog не
   подменяют material presence или identity и не переносят art между choices.
6. Emblems находятся внутри existing event `ExcludeSemantics`; combined reward
   label с localized item name и literal quantity остаётся единственным
   accessibility announcement. Journal остаётся read-only.
7. Home API, backend, persistence, commands, rewards, inventory, requirements,
   assets, external validation и immutable `alpha-rc1` не меняются.

## Последствия

- optional material reward получает существующую visual identity рядом со
  своим accepted choice;
- known art зависит от stable item ID, future IDs остаются neutral;
- choices без material не получают ложный placeholder;
- locked/non-READY и cross-surface decoys не создают ложные emblems;
- accessibility не получает duplicate image announcement или action semantics;
- изменение обратимо на mobile presentation уровне.

## Откат

Удалить trailing material emblems, integration coverage и этот record.
Existing READY-event scene, choice signals/copy/semantics, Home contract,
rewards и commands останутся без изменений.
