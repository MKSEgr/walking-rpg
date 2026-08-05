# ADR 0006: начисление энергии через wallet projection и append-only ledger

- **Статус:** Accepted for first playable
- **Дата:** 2026-07-25

## Контекст

Activity sync уже рассчитывает `energyGranted`, но до этого значения существовали только в response и не становились игровым балансом. Это позволяло показать награду, но не позволяло безопасно потратить её на экспедицию, восстановить после перезапуска или расследовать спорное начисление.

Операция должна одновременно:

- принять новый activity total;
- вычислить энергию;
- изменить баланс;
- записать источник изменения;
- сохранить идемпотентный response.

Частично выполненная операция недопустима.

## Решение

1. Вводится `economy_wallet` — транзакционная проекция текущего баланса по `userId + currencyCode`.
2. Вводится `economy_ledger` — append-only журнал ненулевых изменений баланса.
3. Первая валюта — `ENERGY`.
4. Начисление за шаги имеет `reasonCode = ACTIVITY_STEPS` и `sourceType = ACTIVITY_SYNC`.
5. Уникальность `(userId, currencyCode, sourceType, sourceKey)` защищает от двойной ledger-записи.
6. Исторический `sourceKey` для activity sync строился из length-prefixed
   `deviceId` и `idempotencyKey`. Новые ledger entries используют
   `v2:<requestFingerprint>`, где fingerprint уже канонически связывает user,
   device, local date, business payload и key, но не содержит raw payload.
   Это отделяет новую operation generation от старой после retention receipt.
7. Wallet row блокируется `SELECT ... FOR UPDATE`; activity flow дополнительно использует user-level PostgreSQL advisory transaction lock.
8. Activity state, wallet update, ledger insert и processed response сохраняются одной Spring transaction.
9. При `energyGranted = 0` кошелёк создаётся/читается, но ledger entry не добавляется и версия экономики не увеличивается.
10. Response activity sync дополняется:

```text
energyBalanceAfter — баланс сразу после исходной операции
economyVersion     — версия wallet после исходной операции
```

11. Идемпотентный повтор возвращает сохранённый snapshot, а не перечитывает самый новый баланс.
12. Exact replay и payload conflict гарантируются, пока существует
    `processed_activity_sync`. После retention cleanup повторное использование
    key обрабатывается как новая generation: дневной high-watermark исключает
    повторную награду за уже принятые шаги, а fingerprint-based ledger source
    исключает возврат исторического wallet snapshot или ложный conflict со
    старой append-only записью.

## Почему wallet и ledger нужны одновременно

Только ledger даёт надёжный аудит, но вычислять сумму всей истории при каждом запросе дорого и неудобно для optimistic concurrency. Только mutable wallet быстро читается, но не объясняет происхождение баланса.

Поэтому:

- ledger является журналом фактов;
- wallet является проверяемой проекцией;
- обе записи меняются атомарно.

## Миграция существующих данных

Flyway V2 восстанавливает ENERGY balance из ранее сохранённых `processed_activity_sync.energy_granted`:

- создаёт wallet для существующих пользователей;
- рассчитывает исторические `energyBalanceAfter` и `economyVersion` оконными функциями;
- создаёт ledger entries для положительных начислений;
- добавляет economy snapshot в processed response.

Это сохраняет семантику повторов уже обработанных sync после обновления схемы.

## Последствия

Плюсы:

- энергия переживает перезапуск;
- повтор sync не создаёт двойное начисление;
- reuse key после retention receipt не рассинхронизирует command response и
  текущую wallet projection;
- можно расследовать каждую операцию;
- следующий срез может безопасно списывать энергию на экспедицию;
- rollback не оставляет частичное состояние.

Ограничения:

- пока поддерживается только credit ENERGY;
- debit и запрет отрицательного баланса будут добавлены вместе с экспедицией;
- отдельного wallet query endpoint пока нет;
- сверка wallet projection с ledger sum пока не автоматизирована.
