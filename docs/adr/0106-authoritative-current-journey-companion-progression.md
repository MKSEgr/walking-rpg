# ADR 0106: authoritative current-journey companion progression

- **Статус:** Accepted
- **Дата:** 2026-08-28
- **Связанная задача:** [issue #501](https://github.com/MKSEgr/walking-rpg/issues/501)

## Контекст

Home snapshot уже содержит accepted active companion `level` и `bond`, а
current-journey journal показывает его identity. Platform snapshot также
проецирует pet progression, а decision rewards и journey history содержат bond
deltas/totals с другой семантикой. Эти соседние источники не должны подменять
current Home progression.

## Решение

1. Journal читает companion level/bond только из accepted Home snapshot.
2. Platform active pet level/bond, decision reward delta, completion/chronicle
   totals и local catalog state не подменяют и не восстанавливают Home facts.
3. Label не агрегирует rewards, не прогнозирует level/evolution и не применяет
   client-owned progression rules.
4. Label получает одну dedicated semantics node без actions, пригодную для RU/EN
   compact large-text layout.
5. Species/evolution-stage presentation, Home API, backend, persistence,
   commands, rewards и external validation не меняются.

## Последствия

- игрок видит accepted level и bond активного спутника рядом с identity;
- RU/EN используют одинаковые server-owned числовые facts;
- Platform state и persisted reward history сохраняют собственную семантику;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal progression label, localization keys, tests и этот
documentation record. Home companion contract и остальные pet surfaces
останутся без изменений.
