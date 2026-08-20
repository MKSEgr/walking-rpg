# ADR 0044: lifetime route decision chronicle

- **Статус:** Accepted
- **Дата:** 2026-08-20
- **Связанная задача:** [issue #355](https://github.com/MKSEgr/walking-rpg/issues/355)

## Контекст

Current и recent journey recaps сохраняют полные persisted `decisions[]`, но
архив ограничен пятью походами. Lifetime `journeyChronicle` уже показывает
общий `decisionCount` и разбивку финалов, однако не отвечает, какие решения
формировали весь путь. Mobile не может восстановить такую историю из recent
window, current content или route topology.

Immutable event resolutions содержат persisted event, choice и outcome copy.
Завершение прошлого похода доказывает receipt старта следующего journey, а
authoritative current `COMPLETED` уже имеет ordered decisions до появления
такого receipt.

## Решение

1. Home добавляет optional-compatible ordered `decisionOutcomes[]` с
   `eventId`, `eventTitle`, `choiceId`, `choiceTitle`, `outcomeTitle` и
   положительным `decisionCount`.
2. Repository агрегирует все resolutions receipt-proven походов по полному
   persisted identity/copy и сортирует группы по первому immutable появлению.
3. Service объединяет все decisions authoritative current `COMPLETED` ровно
   один раз. После старта следующего journey те же решения учитываются
   repository и больше не добавляются как current.
4. При наличии breakdown сумма entry `decisionCount` обязана точно совпадать с
   lifetime `decisionCount`. Backend опускает неполный additive массив; mobile
   принимает omission, но fail-closed отклоняет malformed, duplicate,
   non-positive или count-mismatched данные.
5. UI показывает lifetime decisions отдельно от totals и финалов, сохраняет
   server order и включает каждую запись в единую RU/EN accessibility summary.

## Последствия

- lifetime decision history больше не ограничена пятью recent recaps;
- content republish не меняет сохранённые названия или identity решений;
- payload растёт на число уникальных persisted decision identities;
- schema migration, изменение content, topology, economy и inventory не нужны;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Поле `journeyChronicle.decisionOutcomes` и UI-блок можно удалить. Parser уже
поддерживает omission, поэтому database rollback, history rewrite и cache
migration не требуются.
