# ADR 0046: pilot XP breakdown in journey recaps

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #359](https://github.com/MKSEgr/walking-rpg/issues/359)

## Контекст

Current `completionRecap` и недавние `recentJourneyRecaps[]` уже сохраняют
общий `pilotExperienceGained`, решения, финал, связь спутников и материалы
конкретного похода. Но XP остаётся безымянным, хотя immutable event resolutions
содержат persisted `pilot_id`, `pilot_name` и фактически выданный
`pilot_experience_gained`.

Lifetime `journeyChronicle.pilotExperienceRewards[]` объясняет вклад пилотов
во всех завершённых походах, но не может быть источником per-journey identity:
он намеренно агрегирован и не сохраняет границы каждого отдельного маршрута.

## Решение

1. Current и recent journey recap добавляют optional-compatible ordered
   `pilotExperienceRewards[]` с persisted `pilotId`, `pilotName` и
   положительным `experienceGained`.
2. Service группирует immutable reward facts exact `journeyNumber` по
   `pilotId + pilotName` в порядке первого появления.
3. Сумма breakdown обязана точно совпадать с совместимым
   `pilotExperienceGained`. Если хотя бы одна положительная XP-запись не имеет
   полной persisted identity, backend опускает весь additive массив.
4. Mobile принимает legacy omission как generic XP, а при наличии массива
   проверяет форму, положительный XP, уникальность identity и exact sum.
5. Current completion и recent archive показывают ordered именные RU/EN chips
   и включают полный breakdown в единую accessibility summary.

## Последствия

- каждый завершённый поход объясняет XP сохранёнными именами пилотов
  независимо от current content republish;
- неполные legacy rows не превращаются в частичную или выдуманную историю;
- lifetime и per-journey projections используют одинаковый persisted identity
  contract, но остаются независимыми агрегатами;
- database migration, изменение XP economy, progression и topology не нужны;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Поле `pilotExperienceRewards` и named recap rendering можно удалить отдельным
revert. Parser уже поддерживает omission, поэтому database rollback, history
rewrite и cache migration не требуются.
