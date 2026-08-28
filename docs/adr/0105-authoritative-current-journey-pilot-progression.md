# ADR 0105: authoritative current-journey pilot progression

- **Статус:** Accepted
- **Дата:** 2026-08-28
- **Связанная задача:** [issue #499](https://github.com/MKSEgr/walking-rpg/issues/499)

## Контекст

Home snapshot уже принимает server-owned pilot `level`, `currentExperience` и
`nextLevelExperience`, проверяет их инварианты и строит remaining XP. Journal
текущего похода показывает pilot identity, но не даёт рядом его accepted
progression. Platform season XP, decision rewards и completion history содержат
похожие числа с другой семантикой и не должны становиться источником current
pilot progression.

## Решение

1. Journal читает pilot level/current/target только из accepted Home snapshot.
2. Remaining XP вычисляется существующим Home getter из тех же current/target,
   без reward aggregation, forecast или client-owned level rules.
3. Label показывается только при `hasPilotExperienceProgress`; legacy direct
   snapshot без progression не показывает ложные `0 / 0`.
4. Platform season level/XP, decision rewards, completion/chronicle totals и
   local content не подменяют и не восстанавливают Home progression.
5. Label получает одну dedicated semantics node без actions, пригодную для RU/EN
   compact large-text layout.
6. Home API, backend, persistence, XP rules, commands, rewards и external
   validation не меняются.

## Последствия

- игрок видит accepted уровень пилота и точный XP progress рядом с identity;
- одинаковые Home facts дают согласованные RU/EN current/target/remaining;
- legacy direct snapshots остаются читаемыми без фиктивного progression;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal progression label, localization keys, tests и этот
documentation record. Home progression contract и остальные pilot surfaces
останутся без изменений.
