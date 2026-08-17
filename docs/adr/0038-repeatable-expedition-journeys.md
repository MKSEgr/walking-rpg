# ADR 0038: repeatable expedition journeys

- **Статус:** Accepted
- **Дата:** 2026-08-17
- **Связанная задача:** [issue #315](https://github.com/MKSEgr/walking-rpg/issues/315)

## Контекст

После финального event resolution `expedition_progress` навсегда оставался
`COMPLETED`. Игрок не мог повторить основной loop, а старая
unique constraint на `processed_event_resolution` разрешала каждый event
только один раз за всю жизнь аккаунта.

Новый цикл не должен превращаться в сброс аккаунта: pilot XP, pet bond и
эволюция, skills, inventory, unique items и equipment являются
постоянной прогрессией. Команда также должна сохранить existing
idempotency, durable ACK, multi-device и rolling-deploy boundaries.

## Решение

Backend добавляет:

```text
POST /api/v1/expeditions/{expeditionId}/journeys
```

Request содержит `expectedJourneyNumber` и `idempotencyKey`. Первое поле —
compare-and-set guard для stale mobile/второго устройства; второе — exact replay
после потери response.

Под transaction-scoped user+expedition lock сервис:

1. ищет immutable processed response и replay-ит его до проверок current state;
2. запрещает новую команду при pending event receipt;
3. сравнивает expected/current journey и требует `COMPLETED`;
4. заменяет только route state на нулевой `IN_PROGRESS` первого узла
   active content и увеличивает journey number;
5. сохраняет route, cycle и response одной транзакцией.

ENERGY на start не списывается; следующий `advance` тратит её по обычным
правилам. Home проецирует additive `journeyNumber`. Flutter хранит
`EXPEDITION_JOURNEY_START` в GAMEPLAY outbox до network send, перечитывает Home
после успеха и не разрешает start из cached state или до ACK.

## Хранение и migration

Flyway V34 создаёт `expedition_journey_cycle` и
`processed_expedition_journey_start`. Existing progress backfill-ится как journey 1
без изменения самого progress. `processed_event_resolution.journey_number`
получает compatibility default 1; uniqueness становится
`(user_id, expedition_id, event_id, journey_number)`.

После появления journey 2 pre-V34 binary не может корректно записать
event journey number. Поэтому нужен полный drain pre-V34 instances до разрешения
второго похода, а binary rollback после него запрещён.

## Последствия

- главный gameplay loop становится повторяемым без нового content fork;
- один event может честно выдать награду в разных походах, но exact replay
  и uniqueness по-прежнему защищают один поход;
- balance повторных наград и UX нового цикла требуют beta evidence.
