# ADR 0045: lifetime pilot experience chronicle

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #357](https://github.com/MKSEgr/walking-rpg/issues/357)

## Контекст

Lifetime `journeyChronicle` уже показывает общий XP всех подтверждённых
завершённых походов, но не объясняет вклад persisted pilot identities. Mobile
не может корректно восстановить lifetime history из текущего pilot
progression, current content или пяти recent recaps.

Immutable event resolutions уже содержат `pilot_id`, `pilot_name` и фактически
выданный `pilot_experience_gained`. Завершение прошлого похода доказывает
receipt старта следующего journey, а текущий поход считается завершённым
только по authoritative состоянию `COMPLETED`.

## Решение

1. Home добавляет optional-compatible ordered `pilotExperienceRewards[]` с
   persisted `pilotId`, `pilotName` и положительным `experienceGained`.
2. Repository выбирает положительный XP только из immutable resolutions
   receipt-proven завершённых походов, группирует его по persisted
   `pilotId + pilotName` и сортирует группы по первому immutable появлению.
3. Service объединяет historical группы с reward facts authoritative current
   `COMPLETED` ровно один раз. После старта следующего journey тот же поход
   учитывается repository и больше не добавляется как current.
4. Сумма `pilotExperienceRewards[].experienceGained` обязана точно совпадать с
   `pilotExperienceGained`. Backend опускает неполный additive массив; current
   pilot content, progression total и recent archive не являются источниками
   проекции.
5. Mobile принимает legacy omission как общий XP. При наличии массива он
   проверяет форму, положительный XP, уникальность persisted identity и exact
   sum, затем показывает ordered именные RU/EN chips и одну полную
   accessibility summary.

## Последствия

- lifetime-летопись объясняет XP сохранёнными именами пилотов независимо от
  current content republish;
- история длиннее recent archive остаётся полной;
- payload растёт только на число уникальных persisted pilot identities;
- schema migration, изменение XP economy, progression и topology не нужны;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Поле `journeyChronicle.pilotExperienceRewards` и именные XP chips можно
удалить. Parser уже поддерживает omission, поэтому database rollback, history
rewrite и cache migration не требуются.
