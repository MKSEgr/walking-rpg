# ADR 0063: authoritative daily goal feedback

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #393](https://github.com/MKSEgr/walking-rpg/issues/393)

## Контекст

Home уже получает server-owned `dailySteps` и персональный `dailyGoal`, но
показывает игроку только дробь и процент. Чтобы понять ближайший ориентир,
игроку приходится самостоятельно вычитать accepted total из цели. Читать для
этого Health history или optimistic client sync state нельзя: они могут
расходиться с последним принятым Home snapshot.

## Решение

1. Mobile вычисляет `remainingDailySteps` как
   `max(dailyGoal - dailySteps, 0)` только из accepted Home snapshot.
2. Пока remaining положителен, RU/EN copy называет его с корректной plural
   form; при равенстве или превышении цели выводится reached-состояние.
3. Surplus steps не показываются как награда, ENERGY, новый tier или обещание
   будущего server outcome.
4. Exact total и feedback входят в одну semantics summary, а visual children
   исключаются из повторного screen-reader announcement.
5. Daily-goal calculation, weekly rhythm, Home API, backend и persistence не
   меняются.

## Последствия

- ближайший дневной ориентир понятен без ручного расчёта;
- accepted total остаётся единственным источником presentation state;
- goal reached не подменяет authoritative reward/economy command;
- compact Home получает одну короткую fluid line под exact total.

## Откат

Удалить derived getters, RU/EN feedback, semantics wrapper, tests и
documentation additions. API, persisted data и migration rollback не
затрагиваются.
