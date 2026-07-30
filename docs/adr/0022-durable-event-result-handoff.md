# ADR 0022: Durable event-result handoff

- **Статус:** Accepted for alpha first journey
- **Дата:** 2026-07-29

## Контекст

Event resolution уже был идемпотентной server-authoritative транзакцией:
expedition transition, pilot XP, bond активного питомца, material reward и
immutable response сохранялись вместе. Но показ результата оставался
транзиентным mobile-событием.

Если backend успел принять resolution, а HTTP response потерялся, outbox мог
replay-ить исходную команду. Этого недостаточно для handoff пользователю: после
успешного ответа приложение могло завершиться до показа reward UI, а
authoritative expedition уже указывала на следующий узел. Старый
`unlockedEvent` не должен был оставаться каноническим контейнером результата.

Требуется отдельный server-owned факт: какой результат уже создан, но ещё не
подтверждён пользователем. Он должен переживать network ambiguity, process
restart и offline read fallback, не начислять награду повторно и не позволять
перепрыгнуть карточку прямым gameplay-вызовом.

## Решение

### Durable receipt

Каждый новый event resolution создаёт UUID `receiptId` и сохраняет его в
`processed_event_resolution` вместе с:

- immutable choice/outcome snapshot;
- pilot, pet и nullable material reward snapshot;
- delivery mode `handoffRequired`;
- nullable `nextNode` (`nodeId`, `name`);
- временем resolution;
- nullable `acknowledgedAt`.

Receipt и reward создаются в той же транзакции, что и expedition transition,
progression и inventory. Exact replay исходной resolution-команды возвращает
тот же `receiptId`, `handoffRequired`, reward и `nextNode`.

`POST /api/v1/events/{eventId}/resolve` добавляет в response:

```json
{
  "receiptId": "22222222-2222-2222-2222-222222222222",
  "handoffRequired": true,
  "nextNode": {
    "nodeId": "ash-orbit",
    "name": "Пепельная орбита"
  }
}
```

У финального события `nextNode = null`.

### Capability negotiation

Durable handoff включается одновременно request-header и cluster-wide
activation gate:

```http
X-Walking-RPG-Capabilities: durable-event-result-v1
```

```text
DURABLE_EVENT_RESULT_HANDOFF_ENABLED=true
```

При распознанной capability и активном gate backend сохраняет
`handoffRequired = true`, оставляет `acknowledgedAt = null` и включает результат
в home pending projection и gameplay gate. Без capability или при выключенном
gate backend сохраняет `handoffRequired = false`, а database trigger заполняет
`acknowledgedAt = serverTime`: старый mobile получает привычный response и не
блокируется после события.

Capability не входит в idempotency fingerprint. Exact replay сохраняет delivery
mode первого запроса: повтор с добавленной или удалённой capability не меняет
ACK lifecycle уже committed результата. Response всегда сообщает сохранённый
`handoffRequired`, поэтому mobile принимает решение по response, а не по факту
отправки header.

Новый mobile принимает legacy response старого backend без `receiptId`,
`handoffRequired` и `nextNode` как немедленно доставленный результат. До
activation это разрешает backend-first и mobile-first rollout.

Gate остаётся выключенным при применении V10, rolling deploy нового backend и
обновлении mobile. Его можно включить только после полного drain старых backend
instances. Это исключает replay потерянного capable-response через старый DTO,
который не умеет вернуть receipt или применить pending gate.

После активации старый binary нельзя возвращать в pool. Для rollback нужно:

1. выключить gate на всём новом backend pool;
2. дождаться, пока запрос ниже вернёт `0`;
3. только затем развернуть старый binary.

```sql
SELECT count(*)
FROM processed_event_resolution
WHERE handoff_required
  AND acknowledged_at IS NULL;
```

Если capable-устройство уже создало pending receipt, старый клиент того же
аккаунта не умеет подтвердить его и должен быть обновлён либо пользователь
должен завершить handoff на capable-устройстве.

### Home pending projection

`GET /api/v1/home` возвращает nullable top-level `pendingEventResult`.
Projection содержит полный immutable result snapshot и `resolvedAt`, поэтому
не зависит от текущего `expedition.unlockedEvent`.

Mobile показывает pending result отдельной карточкой:

- карточка восстанавливается после reload или process restart;
- nullable `nextNode` определяет текст продолжения или завершения главы;
- cached home может показать карточку, но не разрешает mutation;
- optimistic XP, bond, inventory или expedition state не создаются.

### Явное acknowledgement

Пользователь подтверждает результат endpoint-ом:

```http
POST /api/v1/event-results/{receiptId}/acknowledge
Authorization: Bearer <access-token>
Accept: application/json
```

Request не имеет body. `receiptId` — единственный server-side idempotency
scope. Backend проверяет owner из authenticated context и атомарно устанавливает
`acknowledgedAt` только один раз. Replay того же receipt возвращает тот же
`acknowledgedAt`; `serverTime` ACK-response также равен сохранённому времени
первого acknowledgement.

Неизвестный или принадлежащий другому пользователю receipt возвращает
`404 EVENT_RESULT_NOT_FOUND`, не раскрывая owner.

Mobile использует отдельную durable команду
`EVENT_RESULT_ACKNOWLEDGEMENT` в GAMEPLAY lane:

1. сохраняет `receiptId` до первой сетевой попытки;
2. отправляет bodyless ACK;
3. при неоднозначном ответе replay-ит тот же receipt после restart;
4. после подтверждённого ACK перечитывает authoritative home.

Локальный command key остаётся внутренней деталью outbox и не входит в
HTTP-контракт.

### Gameplay gate

Пока у пользователя существует pending receipt соответствующей экспедиции,
backend отклоняет:

- новый expedition advance;
- новый event resolution.

Проверка выполняется внутри существующей user+expedition serialization
boundary и возвращает `409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED` с
`receiptId/eventId`. UI также блокирует эти действия, но server-side gate
остаётся каноническим инвариантом.

ACK только отмечает handoff: он не меняет expedition, progression, economy или
inventory повторно.

### Upgrade

Flyway V10 добавляет `receipt_id`, `handoff_required`, `next_node_id`,
`next_node_name` и `acknowledged_at`, unique constraint receipt и partial
unique index `(user_id, expedition_id)` для единственного capable pending
result. Defaults `receipt_id = gen_random_uuid()` и
`handoff_required = false` сохраняют прежнюю форму SQL `INSERT`. Trigger
`BEFORE INSERT` физически выставляет `acknowledged_at = server_time` любому
legacy writer, который не объявил durable handoff. Check constraint запрещает
неподтверждённую строку с `handoff_required = false`.

Результаты, созданные до V10, уже были показаны старым UI. Миграция выдаёт им
UUID, но заполняет `acknowledged_at = server_time`, чтобы исторические награды
не всплывали после upgrade. Только новый backend с распознанной capability
создаёт `handoff_required = true` и `acknowledged_at = null`.

Account export включает receipt, delivery mode, next-node и acknowledgement
fields. Existing account deletion удаляет rows вместе с остальными данными
пользователя.

## Рассмотренные альтернативы

### Оставить snackbar/result screen только в памяти

Отклонено: теряет handoff после process death и не восстанавливает результат,
если resolution commit произошёл до потери response.

### Хранить resolved outcome внутри текущего expedition event

Отклонено: expedition уже должна перейти на следующий узел, а historical event
не является текущим progress state. Это смешивает progression и UI delivery.

### Считать любой `GET /home` неявным ACK

Отклонено: успешный network read не доказывает, что пользователь увидел
карточку. Background/startup reload мог бы скрыть награду до первого frame.

### Показать все legacy resolutions как pending

Отклонено: пользователи повторно увидели бы уже потреблённые результаты и могли
бы принять historical reward за новое начисление.

## Последствия

Плюсы:

- committed reward нельзя потерять между backend response и UI;
- exact resolution replay и result acknowledgement имеют разные ясные scopes;
- home остаётся единственным authoritative recovery read-model;
- следующий gameplay step нельзя начать до явного handoff;
- database constraint не позволяет capable/direct writer создать второй
  pending result той же экспедиции, а legacy writer auto-acknowledged;
- cluster activation не позволяет mixed old/new backend pool существовать
  после появления capable pending receipts;
- offline cache сохраняет видимость результата без разрешения mutation;
- upgrade не показывает legacy rewards повторно.

Стоимость:

- event flow получает дополнительный HTTP round trip и durable command type;
- rollout получает явный activation step и rollback precondition;
- `processed_event_resolution` хранит ACK lifecycle, а не только immutable
  command response;
- pending receipt временно блокирует gameplay и требует capable-клиента и
  явного recovery UX при постоянной terminal error;
- receipt history/operator UI в этот срез не входят.

## Границы

Решение не добавляет:

- background command delivery;
- production push;
- physical-device validation;
- store signing/submission;
- нелинейные ветки или новый content;
- отдельный пользовательский журнал всех старых receipts.

Эти gates сохраняют прежний статус и требуют собственного evidence.

## Проверки

Срез покрывается:

- API tests `receiptId`/`nextNode` и bodyless owner-scoped ACK;
- PostgreSQL integration tests pending home, concurrent/stable ACK replay без
  повторного physical update, exact advance replay и gameplay gate;
- Flyway V10 clean/upgrade test с backfilled и rolling legacy auto-ACK;
- capability-order tests сохраняют первый delivery mode при exact replay;
- controller test не принимает capability до cluster activation;
- mobile parsing старого/new response, result-card и cached read-only widget
  tests;
- persist-before-send/restart replay ACK в GAMEPLAY outbox;
- first-journey finish, который подтверждает receipt перед переходом в основной
  shell.

Server-authoritative наблюдаемость первого ACK и отделение explicit delivery от
legacy auto-ACK определены в
[ADR 0023](0023-acknowledged-first-journey-result.md).
