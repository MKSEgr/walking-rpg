# ADR 0120: authoritative saved journey decision event scenes

- **Статус:** Accepted
- **Дата:** 2026-08-30
- **Связанная задача:** [issue #531](https://github.com/MKSEgr/walking-rpg/issues/531)

## Контекст

Current `decisionLog` и раскрываемая recent archive history уже показывают
literal persisted event identity, exact choice signal и reward art. При этом
каждая запись события остаётся text-only, хотя exact `eventId` может безопасно
переиспользовать reviewed `ExpeditionEventScene`.

Historical visual нельзя выбирать из текущего READY event или других mutable
snapshot facts. Они могут относиться к другому моменту похода, а совпадающие
title, choice copy или content entry не доказывают persisted identity.

## Решение

1. Shared renderer current и expanded recent decision entries показывает
   `ExpeditionEventScene` только при exact non-empty persisted `entry.eventId`.
2. Scene получает тот же literal persisted `entry.eventTitle`; он не
   локализуется повторно и не используется для выбора artwork.
3. Known reviewed ID выбирает established asset, unknown/future ID использует
   neutral code-native fallback existing component.
4. Empty value, возможный только через defensive direct construction,
   fail-closed не создаёт scene. Accepted Home JSON по-прежнему требует
   non-empty event ID.
5. Dispatch не читает current READY event, expedition phase, route, Platform,
   localized names, choice/outcome copy, rewards, catalog или соседние
   decisions.
6. Scene декоративна и остаётся внутри existing entry `ExcludeSemantics`.
   Literal event/choice/outcome/reward/timestamp copy, ordering, read-only
   behavior и одна localized decision semantics node не меняются.
7. Home API, backend, persistence, commands, content, assets, external
   validation и immutable `alpha-rc1` не меняются.

## Последствия

- immutable current и archived decisions получили reviewed event identity из
  собственного persisted ID;
- future events остаются визуально neutral без вывода identity из display
  copy или current state;
- shared renderer сохраняет одинаковое presentation-поведение current и
  recent history;
- изменение остаётся обратимым на mobile presentation уровне.

## Откат

Удалить `ExpeditionEventScene` из shared decision renderer, соответствующие
widget assertions, milestone и этот record. Persisted copy, choice/reward art,
Home contract, backend и commands останутся без изменений.
