# ADR 0118: authoritative saved journey decision choice signals

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #527](https://github.com/MKSEgr/walking-rpg/issues/527)

## Контекст

Current journey journal и раскрытая recent archive history уже показывают
literal immutable `decisionLog` entries. Для тех же exact event/choice pairs
существует reviewed `EventChoiceSignal` vocabulary, но сохранённый выбор пока
отмечен generic arrow и визуально теряет identity, известную READY preview.

History нельзя обогащать из current content. Текущий READY event, Platform
snapshot, route или mutable catalog могут относиться уже к другому состоянию.
Dispatch по choice ID без event ID или по literal title также дал бы знакомый
mark future/legacy pair, которой он не принадлежит.

## Решение

1. Shared renderer current `decisionLog` и expanded recent archive history
   передаёт в `EventChoiceSignalLayout` только exact persisted
   `entry.eventId + entry.choiceId`.
2. Known reviewed pair получает established mark. Unknown, future и legacy
   pair получает existing neutral fallback, включая знакомый choice ID внутри
   неизвестного event.
3. Signal не читает и не сверяет current READY event, Platform snapshot,
   route, names, event/choice/outcome copy, rewards, progression или catalog.
4. Persisted event title, choice title, outcome title/summary, rewards,
   timestamp и server ordering остаются literal и authoritative.
5. Signal декоративен и расположен внутри existing entry `ExcludeSemantics`.
   Каждая запись остаётся одной localized semantics node без image/action
   announcement и остаётся read-only.
6. Те же правила применяются к current и recent entries через один widget;
   archive не получает отдельный resolver.
7. Home API, backend, persistence, commands, content, assets, external
   validation и immutable `alpha-rc1` не меняются.

## Последствия

- immutable saved decisions получили ту же reviewed visual identity, что и их
  exact event/choice pair в preview;
- future и legacy history остаётся честно neutral и не зависит от current
  mutable state;
- literal historical copy, ordering и accessibility contract сохраняются;
- изменение обратимо на mobile presentation уровне.

## Откат

Вернуть generic choice arrow в shared decision entry и удалить integration
coverage и этот record. Persisted journal copy, recent archive, Home contract,
commands и backend останутся без изменений.
