# ADR 0041: lifetime companion bond chronicle

- **Статус:** Accepted
- **Дата:** 2026-08-19
- **Связанная задача:** [issue #349](https://github.com/MKSEgr/walking-rpg/issues/349)

## Контекст

Lifetime `journeyChronicle` уже показывает общий companion bond всех
подтверждённых завершённых походов, но не объясняет вклад отдельных спутников.
Именная разбивка есть только в current и recent recap, ограниченном пятью
прошлыми походами. Mobile не может корректно восстановить lifetime history из
этого архива, текущего питомца или progression total.

Исторические event resolutions уже содержат immutable `pet_id`, `pet_name` и
фактически выданный `pet_bond_gained`. Завершение прошлого похода доказывается
receipt старта следующего journey, а текущий поход считается завершённым
только по authoritative состоянию `COMPLETED`.

## Решение

1. Home добавляет к `journeyChronicle` ordered `petBondRewards[]` без изменения
   существующего `petBondGained`.
2. Repository выбирает только положительную связь из immutable resolutions
   receipt-proven завершённых походов, группирует её по persisted
   `petId + petName` и сортирует группы по первому immutable появлению.
3. Service объединяет historical группы с breakdown authoritative current
   `COMPLETED` ровно один раз. После старта следующего journey тот же поход
   учитывается repository и больше не добавляется как current.
4. Сумма `petBondRewards[].bondGained` обязана точно совпадать с
   `petBondGained`; current content, active pet, progression delta и recent
   archive не являются источниками этой проекции.
5. Mobile принимает legacy omission как общий неназванный итог. При наличии
   массива он проверяет форму, положительную связь, уникальность persisted
   identity и exact sum, затем показывает ordered именные RU/EN chips и одну
   accessibility summary.

## Последствия

- lifetime-летопись объясняет распределение накопленной связи по фактической
  истории спутников, включая имена, сохранённые на момент решения;
- история длиннее recent archive остаётся полной и не зависит от current
  content republish;
- schema migration, изменение экономики и material aggregation не нужны;
- payload увеличивается только на число уникальных persisted companion
  identities, а legacy backend/cache остаются совместимыми;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Поле `journeyChronicle.petBondRewards` можно перестать проецировать и удалить
именные chips, вернув mobile к существующему `petBondGained`. Additive omission
уже поддерживается parser, поэтому database rollback, переписывание history и
cache migration не требуются.
