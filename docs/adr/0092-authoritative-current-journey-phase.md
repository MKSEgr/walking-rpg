# ADR 0092: authoritative current-journey phase

- **Статус:** Accepted
- **Дата:** 2026-08-23
- **Связанная задача:** [issue #454](https://github.com/MKSEgr/walking-rpg/issues/454)

## Контекст

Home уже публикует required `expedition.status`, но journal показывает номер,
start time и decisions без короткой phase guidance. Вывод phase из доступной
energy, unresolved event или visible decisions переносил бы server rules на
mobile и мог расходиться с accepted state.

## Решение

1. Mobile принимает только `IN_PROGRESS`, `EVENT_READY` и `COMPLETED`.
2. Journal локализует literal accepted status в одну visible RU/EN label.
3. Одна semantics node объявляет ту же phase без дублирования visible text.
4. Energy, route trail, decision log, unlocked event и completion recap не
   используются для вывода phase.
5. Projection не меняет Home commands, backend, persistence или resolution.

## Последствия

- игрок получает явный current-journey state рядом с журналом;
- cached snapshot сохраняет phase принятого server response;
- неизвестный status отклоняется fail-closed вместо эвристического UI.

## Откат

Удалить phase labels и validation accepted status set из mobile, затем удалить
tests и documentation. Home API и server status останутся без изменений.
