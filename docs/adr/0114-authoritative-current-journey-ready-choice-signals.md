# ADR 0114: authoritative current-journey READY choice signals

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #519](https://github.com/MKSEgr/walking-rpg/issues/519)

## Контекст

Current-journey journal уже показывает accepted available READY-choice title,
description, optional requirement и reward в server order. Home и First
Journey одновременно используют existing `EventChoiceSignalLayout`, который
выбирает reviewed code-native mark по exact event/choice pair и имеет neutral
fallback для future content.

Journal не должен выбирать mark из choice copy, requirement/reward, Platform
state, expedition phase, route trail, decision history или local catalog.
Знакомый choice ID внутри другого или future event не подтверждает ту же
identity. Existing event block уже публикует одну combined semantics node,
поэтому отдельная signal semantics создала бы duplicate announcement.

## Решение

1. Journal строит `EventChoiceSignalLayout` только для accepted
   `availableChoices` accepted Home `unlockedEvent` со status exact `READY`.
2. Каждый layout получает exact `eventId` и `choiceId` той же accepted choice,
   чьи title, description, optional requirement и reward он обрамляет.
3. Только exact reviewed event/choice pair выбирает known mark. Unknown future
   pair получает neutral signal; title, description, requirement и reward не
   участвуют в dispatch.
4. Journal сохраняет accepted server ordering и не выполняет requirements или
   availability повторно. Locked, absent, `RESOLVED` и unknown event status
   fail-closed не создают signal.
5. Platform event/progression, expedition phase, route trail, decision history
   и catalog не подменяют event identity, choice identity или availability.
6. Signals находятся внутри existing event `ExcludeSemantics`; прежняя
   combined semantics node для event и choice facts остаётся единственным
   accessibility announcement. Journal остаётся read-only.
7. Home API, backend, persistence, commands, outcomes, rewards, requirements,
   assets, external validation и immutable `alpha-rc1` не меняются.

## Последствия

- available READY choices получают существующую reviewed visual vocabulary;
- known marks зависят от полной stable pair, future pairs остаются neutral;
- accepted ordering и copy/reward pairing не меняются;
- locked/non-READY и cross-surface decoys не создают ложные signals;
- accessibility не получает duplicate announcement или action semantics;
- изменение обратимо на mobile presentation уровне.

## Откат

Удалить nested choice-signal layouts, integration coverage и этот record.
Existing READY-event scene/copy/semantics, Home contract, choices и commands
останутся без изменений.
