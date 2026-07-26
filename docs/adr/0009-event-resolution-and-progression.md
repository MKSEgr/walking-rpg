# ADR 0009: идемпотентное разрешение события и постоянный progression

- **Статус:** Accepted for first playable
- **Дата:** 2026-07-26

## Контекст

Экспедиция уже могла достигнуть первого узла и открыть `signal-source-v1`, но состояние останавливалось на `EVENT_READY`. Для завершения первого игрового цикла требовалось:

- показать server-owned варианты решения;
- необратимо зафиксировать выбор;
- выдать разные награды пилоту и питомцу;
- пережить перезапуск backend;
- не допустить двойной награды;
- сохранить exact response для повторного key;
- атомарно завершить экспедицию и progression.

## Решение

1. Вводится endpoint:

```text
POST /api/v1/events/{eventId}/resolve
```

2. Request содержит `choiceId` и `idempotencyKey`.
3. Событие можно разрешить только когда:

```text
expedition.status = EVENT_READY
expedition.unlockedEventId = eventId
```

4. Первый event имеет два choice:

```text
analyze-signal  → +40 pilot XP, +5 pet bond
trust-spark     → +20 pilot XP, +15 pet bond
```

5. После успеха expedition получает `COMPLETED` и новую version.
6. Mutable progression хранится в:

```text
pilot_progress
pet_progress
```

7. Exact response хранится в `processed_event_resolution`.
8. Scope idempotency:

```text
userId + eventId + idempotencyKey
```

9. Fingerprint включает:

```text
eventId + choiceId
```

10. Event resolution использует advisory transaction lock по user + expedition.
11. Expedition completion, pilot reward, pet reward и processed response фиксируются одной транзакцией.
12. `GET /home` возвращает:

- choices при `READY`;
- selected choice и outcome при `RESOLVED`;
- текущие XP/bond из PostgreSQL.

## Почему progression не проводится через economy ledger

ENERGY является валютой и требует wallet/ledger. Pilot XP и pet bond — независимые progression state с отдельными правилами уровня и эволюции. В first playable они хранятся в специализированных таблицах.

Общий progression reward journal может появиться позже, когда возникнут:

- несколько источников XP/bond;
- отмены или компенсации;
- предметные награды;
- расследование сложных цепочек reward.

До этого отдельный журнал добавил бы инфраструктуру без пользовательской ценности.

## Идемпотентность и повтор

- тот же key и choice возвращает исходный response;
- тот же key с другим choice возвращает `IDEMPOTENCY_CONFLICT`;
- новый key после `COMPLETED` возвращает `EVENT_STATE_CONFLICT`;
- повтор не меняет pilot/pet version.

## Последствия

Плюсы:

- first playable замкнут до постоянного результата;
- разные выборы действительно меняют развитие;
- restart/retry безопасны;
- home/mobile отображают server-authoritative outcome.

Ограничения:

- одно событие;
- reward definitions находятся в коде;
- level-up упрощён;
- нет inventory и предметной награды;
- нет общего progression journal.
