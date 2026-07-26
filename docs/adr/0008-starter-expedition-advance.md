# ADR 0008: постоянный progress экспедиции и атомарный расход ENERGY

- **Статус:** Accepted for first playable
- **Дата:** 2026-07-25

> **Расширение:** ADR 0014 сохраняет этот command-контракт, добавляет второй узел и повышает starter content до `starter-v2`.

## Контекст

Шаги уже создают постоянный баланс ENERGY, а главный экран читает актуальный server state. Однако пользователь пока не мог потратить энергию и получить игровой результат.

Первый command-срез должен:

- поддержать partial progress;
- не допустить отрицательного баланса;
- переживать перезапуск;
- быть идемпотентным;
- корректно работать при конкурентных запросах;
- открыть первое событие после достижения порога;
- не вводить CMS и полноценную сюжетную систему раньше времени.

## Решение

1. Вводится endpoint:

```text
POST /api/v1/expeditions/{expeditionId}/advance
```

2. Request содержит `energyToSpend` и `idempotencyKey`.
3. Первый content definition хранится в коде и версионируется `starter-v1`.
4. Поддерживается одна экспедиция `starter-expedition-v1`.
5. Первый узел `outer-beacon` требует 30 ENERGY.
6. При достижении порога status становится `EVENT_READY`, открывается `signal-source-v1`.
7. Mutable state хранится в `expedition_progress`.
8. Exact command response хранится в `processed_expedition_advance`.
9. Перед изменением применяется PostgreSQL advisory transaction lock по user + expedition.
10. ENERGY списывается через economy ledger с:

```text
reasonCode = EXPEDITION_PROGRESS
sourceType = EXPEDITION_ADVANCE
```

11. Wallet row блокируется `FOR UPDATE`.
12. Debit, ledger, progress и processed response фиксируются одной транзакцией.
13. После `EVENT_READY` дальнейший advance запрещён до отдельной команды resolution.
14. `GET /home` агрегирует persistent progress и server-owned content.

## Идемпотентность

Scope:

```text
userId + expeditionId + idempotencyKey
```

Fingerprint включает:

```text
expeditionId + energyToSpend
```

Повтор того же payload возвращает исходный response, включая старые balance/version snapshots. Повтор key с другим amount возвращает `409 IDEMPOTENCY_CONFLICT`.

Economy дополнительно защищена уникальностью:

```text
userId + currency + sourceType + sourceKey
```

## Почему partial progress

Пользователь может тратить доступную энергию частями. Mobile выбирает:

```text
min(availableEnergy, remainingEnergyToNode)
```

Backend всё равно валидирует переданное значение и не позволяет перескочить текущий узел.

## Почему событие пока только READY

Resolution требует отдельного набора решений:

- варианты выбора;
- необратимость результата;
- награды;
- pilot/pet progression;
- следующий node.

Открытие события проверяет полный путь от реальной активности до игрового состояния, не смешивая его с ещё одним крупным доменным срезом.

## Последствия

Плюсы:

- впервые замкнут путь `steps → energy → spend → game progress`;
- баланс и progress не расходятся;
- повтор и конкуренция безопасны;
- home/mobile показывают реальное игровое состояние;
- следующая задача изолирована до event resolution.

Ограничения:

- одна экспедиция;
- один узел;
- один event;
- content definition находится в коде;
- event нельзя разрешить;
- нет progression reward.
