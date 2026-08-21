# ADR 0064: weekly active-day qualification

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #395](https://github.com/MKSEgr/walking-rpg/issues/395)

## Контекст

Server-owned weekly rhythm считает день активным при положительной persisted
accepted activity, независимо от достижения personal `dailyGoal`. Home
показывает обе меры рядом, но без явного объяснения игрок может принять 100%
дневной цели за обязательный порог active day и неверно оценивать rest marker.

## Решение

1. Existing weekly presentation получает одну спокойную RU/EN clarification:
   любая accepted activity делает день ритма активным, а personal goal считается
   отдельно.
2. Copy показывается для каждого accepted weekly object, включая legacy
   aggregate-only object без `days`.
3. Home без `weeklyActivityRhythm` не получает inferred rule or presentation.
4. Clarification входит в единую weekly semantics summary ровно один раз, а
   visible child исключается из повторного объявления.
5. Mobile не читает Health history, historical step totals или client clock и
   не меняет authoritative qualification rule.

## Последствия

- active/rest markers не воспринимаются как результат daily-goal completion;
- мягкий ритм остаётся достижимым без давления выполнить 100% цели каждый день;
- legacy weekly snapshot получает корректное правило без invented dates;
- Home API, backend, persistence, daily-goal calculation и economy не меняются.

## Откат

Удалить qualification copy, presentation, tests и documentation additions.
API, persisted data и migration rollback не затрагиваются.
