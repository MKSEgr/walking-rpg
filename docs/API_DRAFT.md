# API draft

Документ содержит направление и работающие MVP-контракты, но пока не заменяет полноценную OpenAPI-спецификацию.

## Текущие endpoint-ы

### `GET /api/v1/system/info`

Проверка запущенного backend.

### `GET /api/v1/home/demo`

Явное демонстрационное состояние. Production mobile не использует его как silent fallback.

### `GET /api/v1/home?localDate=YYYY-MM-DD`

Возвращает актуальный read-model главного экрана.

Заголовок:

```text
X-User-Id: demo-user-1
```

Пример:

```json
{
  "localDate": "2026-07-25",
  "timeZone": "Europe/Berlin",
  "dailySteps": 6842,
  "dailyGoal": 6000,
  "availableEnergy": 38,
  "activityStateVersion": 1,
  "economyVersion": 2,
  "lastActivitySyncAt": "2026-07-25T11:55:00Z",
  "serverTime": "2026-07-25T12:00:00Z",
  "contentVersion": "starter-v1",
  "pilot": {
    "name": "Навигатор",
    "level": 1
  },
  "pet": {
    "name": "Искра",
    "level": 1
  },
  "expedition": {
    "expeditionId": "starter-expedition-v1",
    "name": "Сигнал из туманного сектора",
    "currentNodeId": "outer-beacon",
    "currentNode": "Внешний маяк",
    "progress": 30,
    "requiredEnergy": 30,
    "status": "EVENT_READY",
    "version": 1,
    "unlockedEvent": {
      "eventId": "signal-source-v1",
      "title": "Источник сигнала",
      "summary": "Маяк отвечает повторяющимся импульсом. Нужно решить, как войти внутрь.",
      "status": "READY"
    }
  }
}
```

Семантика:

- activity относится к `user + localDate`;
- ENERGY wallet глобален для пользователя;
- expedition progress также глобален для пользователя;
- неизвестный пользователь получает zero-state и starter content;
- `GET` не выполняет `INSERT` или `UPDATE`.

### `POST /api/v1/activity/sync`

Принимает накопительный authoritative total, сохраняет дневной high-watermark и начисляет ENERGY через ledger.

Временные заголовки:

```text
X-User-Id: demo-user-1
X-Device-Id: demo-device-1
```

Request:

```json
{
  "localDate": "2026-07-25",
  "timeZone": "Europe/Berlin",
  "authoritativeTotal": 6842,
  "buckets": [],
  "syncCursor": "opaque-cursor",
  "idempotencyKey": "device-date-sequence",
  "attestation": null
}
```

Response:

```json
{
  "acceptedTotal": 6842,
  "acceptedDelta": 6842,
  "energyGranted": 68,
  "energyBalanceAfter": 68,
  "economyVersion": 1,
  "riskStatus": "ACCEPTED",
  "stateVersion": 1,
  "serverTime": "2026-07-25T12:00:00Z"
}
```

Энергия рассчитывается по накопительным порогам:

```text
energyGranted = floor(newAcceptedTotal / 100)
              - floor(previousAcceptedTotal / 100)
```

### `POST /api/v1/expeditions/{expeditionId}/advance`

Тратит ENERGY на постоянный progress экспедиции.

Заголовок:

```text
X-User-Id: demo-user-1
```

Request:

```json
{
  "energyToSpend": 30,
  "idempotencyKey": "starter-expedition-v1-advance-1"
}
```

Response:

```json
{
  "contentVersion": "starter-v1",
  "expeditionId": "starter-expedition-v1",
  "expeditionName": "Сигнал из туманного сектора",
  "energySpent": 30,
  "energyBalanceAfter": 38,
  "economyVersion": 2,
  "progressAfter": 30,
  "requiredEnergy": 30,
  "expeditionVersion": 1,
  "status": "EVENT_READY",
  "currentNodeId": "outer-beacon",
  "currentNodeName": "Внешний маяк",
  "unlockedEvent": {
    "eventId": "signal-source-v1",
    "title": "Источник сигнала",
    "summary": "Маяк отвечает повторяющимся импульсом. Нужно решить, как войти внутрь.",
    "status": "READY"
  },
  "serverTime": "2026-07-25T12:00:00Z"
}
```

Правила:

- `energyToSpend > 0`;
- `energyToSpend` не может превышать остаток до узла;
- wallet не может стать отрицательным;
- partial advance разрешён;
- progress ограничен первым порогом 30 ENERGY;
- после `EVENT_READY` новый advance возвращает `409 EXPEDITION_STATE_CONFLICT`;
- одинаковый key и payload возвращает исходный response;
- тот же key с другим amount возвращает `409 IDEMPOTENCY_CONFLICT`;
- debit, ledger, progress и processed response сохраняются одной транзакцией.

Недостаточный баланс:

```json
{
  "code": "INSUFFICIENT_ENERGY",
  "message": "Недостаточно энергии для операции",
  "details": {
    "availableEnergy": 5,
    "requiredEnergy": 30
  },
  "traceId": "uuid"
}
```

## Планируемые endpoint-ы first playable

```text
POST /api/v1/events/{eventId}/resolve
GET  /api/v1/content/bootstrap
POST /api/v1/pets/{petId}/upgrade
```

## Общие правила

- JSON-поля — camelCase;
- даты/время — ISO-8601;
- команды изменения поддерживают idempotency;
- клиент не передаёт итоговую награду;
- баланс меняется только через ledger;
- ошибки имеют `code`, `message`, `details`, `traceId`;
- API начинается с `/api/v1`;
- destructive изменения требуют новой версии или миграционного периода.
