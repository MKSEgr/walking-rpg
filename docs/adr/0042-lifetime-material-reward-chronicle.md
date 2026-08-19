# ADR 0042: lifetime material reward chronicle

- **Статус:** Accepted
- **Дата:** 2026-08-19
- **Связанная задача:** [issue #351](https://github.com/MKSEgr/walking-rpg/issues/351)

## Контекст

Lifetime `journeyChronicle` уже показывает число завершённых походов, решений,
pilot XP и companion bond с именной разбивкой, но не сохраняет суммарную
историю material rewards. Материалы видны только в current и recent recap,
причём архив ограничен пятью походами. Mobile не может корректно восстановить
lifetime history из этого окна, текущего inventory balance или material
catalog.

Immutable event resolutions уже содержат persisted `material_item_id`,
`material_item_name` и фактически выданный `material_quantity_gained`.
Завершение прошлого похода доказывается receipt старта следующего journey, а
текущий поход считается завершённым только по authoritative состоянию
`COMPLETED`.

## Решение

1. Home добавляет к `journeyChronicle` ordered `materials[]` с persisted
   `itemId`, `itemName` и положительным aggregated `quantity`.
2. Repository выбирает material rewards только из immutable resolutions
   receipt-proven завершённых походов, группирует их по persisted
   `itemId + itemName` и сортирует группы по первому immutable появлению:
   `journey_number`, `expedition_version`, `receipt_id`.
3. Service объединяет historical группы с материалами authoritative current
   `COMPLETED` ровно один раз. После старта следующего journey тот же поход
   учитывается repository и больше не добавляется как current.
4. Current content, inventory balance и recent archive не являются источниками
   lifetime-проекции; она не изменяет выдачу или расход материалов.
5. Mobile принимает legacy omission как пустую разбивку. При наличии массива
   он проверяет форму, положительное quantity и уникальность persisted identity,
   затем показывает ordered RU/EN chips и одну accessibility summary.

## Последствия

- lifetime-летопись показывает фактически выданные материалы даже после их
  расхода и для истории длиннее recent archive;
- persisted names и first-appearance order не меняются при content republish;
- schema migration и изменение экономики не нужны;
- payload растёт только на число уникальных persisted material identities, а
  legacy backend/cache остаются совместимыми;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Поле `journeyChronicle.materials` можно перестать проецировать и удалить
material chips. Additive omission уже поддерживается parser, поэтому database
rollback, переписывание history и cache migration не требуются.
