# ADR 0043: lifetime route finale chronicle

- **Статус:** Accepted
- **Дата:** 2026-08-19
- **Связанная задача:** [issue #353](https://github.com/MKSEgr/walking-rpg/issues/353)

## Контекст

Current и recent journey recaps сохраняют persisted `finalDecision`, но архив
ограничен пятью походами. Lifetime `journeyChronicle` уже показывает totals,
companion bond и material rewards, однако не отвечает, сколько раз игрок
достигал каждого финала. Mobile не может восстановить эту историю из recent
window, current content или route topology.

Immutable event resolutions содержат persisted event, choice и outcome copy.
Завершение прошлого похода доказывает receipt старта следующего journey, а
authoritative current `COMPLETED` уже имеет итог до появления такого receipt.

## Решение

1. Home добавляет optional-compatible ordered `finaleOutcomes[]` с
   `eventId`, `eventTitle`, `choiceId`, `choiceTitle`, `outcomeTitle` и
   положительным `journeyCount`.
2. Repository выбирает последнюю resolution каждого receipt-proven похода по
   descending `expedition_version, receipt_id`, группирует полный persisted
   identity/copy и сортирует группы по первому immutable появлению.
3. Service объединяет final decision authoritative current `COMPLETED` ровно
   один раз. После старта следующего journey тот же финал учитывается
   repository и больше не добавляется как current.
4. При наличии breakdown сумма `journeyCount` обязана точно совпадать с
   `completedJourneyCount`. Если старая history неполна, backend опускает
   additive поле; mobile принимает omission, но fail-closed отклоняет
   malformed, duplicate, non-positive или count-mismatched массив.
5. UI показывает финалы отдельно от наград, сохраняет server order и включает
   каждую запись в единую RU/EN accessibility summary.

## Последствия

- lifetime history больше не ограничена пятью recent recaps;
- content republish не меняет сохранённые названия или identity финалов;
- payload растёт на число уникальных persisted finale identities;
- schema migration, изменение content, topology, economy и inventory не нужны;
- immutable `alpha-rc1` и external validation gates не меняются.

## Откат

Поле `journeyChronicle.finaleOutcomes` и UI-блок можно удалить. Parser уже
поддерживает omission, поэтому database rollback, history rewrite и cache
migration не требуются.
