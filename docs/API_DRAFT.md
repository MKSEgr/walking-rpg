# API draft

Документ фиксирует работающие MVP-контракты, но пока не заменяет полноценную OpenAPI-спецификацию.

## Общие правила

- namespace: `/api/v1`;
- JSON-поля: camelCase;
- даты/время: ISO-8601;
- команды изменения поддерживают idempotency;
- клиент не передаёт рассчитанную награду, баланс, progress или progression;
- ошибки имеют `code`, `message`, `details`, `traceId`;
- до authentication используются временные `X-User-Id` и `X-Device-Id`.

## `GET /api/v1/system/info`

Проверка запущенного backend.

## `GET /api/v1/home/demo`

Явное демонстрационное состояние. Production mobile не использует его как silent fallback.

## `GET /api/v1/home?localDate=YYYY-MM-DD`

Возвращает актуальный read-model главного экрана.

```http
X-User-Id: demo-user-1
```

После завершения первого события response содержит:

```json
{
  "localDate": "2026-07-26",
  "timeZone": "Europe/Berlin",
  "dailySteps": 6842,
  "dailyGoal": 3250,
  "dailyGoalPolicy": {
    "policyVersion": "adaptive-median-v1",
    "source": "ADAPTIVE",
    "baselineSteps": 3000,
    "sampleDays": 3,
    "lookbackDays": 7,
    "minimumSampleDays": 3,
    "defaultGoal": 6000,
    "growthPercent": 5,
    "roundingStep": 250,
    "minimumGoal": 2000,
    "maximumGoal": 12000
  },
  "availableEnergy": 38,
  "activityStateVersion": 1,
  "economyVersion": 2,
  "lastActivitySyncAt": "2026-07-26T06:55:00Z",
  "serverTime": "2026-07-26T07:00:00Z",
  "contentVersion": "starter-v1",
  "pilot": {
    "name": "Навигатор",
    "level": 1,
    "currentExperience": 60,
    "nextLevelExperience": 100,
    "specialization": "Не выбрана"
  },
  "pet": {
    "name": "Искра",
    "species": "Люмин",
    "level": 1,
    "bond": 15,
    "trait": "Чуткий разведчик"
  },
  "expedition": {
    "expeditionId": "starter-expedition-v1",
    "name": "Сигнал из туманного сектора",
    "currentNodeId": "outer-beacon",
    "currentNode": "Внешний маяк",
    "progress": 30,
    "requiredEnergy": 30,
    "status": "COMPLETED",
    "version": 2,
    "unlockedEvent": {
      "eventId": "signal-source-v1",
      "title": "Источник сигнала",
      "summary": "Маяк отвечает повторяющимся импульсом.",
      "status": "RESOLVED",
      "selectedChoiceId": "analyze-signal",
      "selectedChoiceTitle": "Проанализировать сигнал",
      "outcomeTitle": "Карта импульсов",
      "outcomeSummary": "Навигатор выделил безопасный ритм доступа."
    }
  }
}
```

Семантика:

- activity относится к `user + localDate`;
- `dailyGoal` рассчитывается backend-ом по медиане положительных accepted total за предыдущие семь локальных дней;
- при менее чем трёх валидных днях возвращается стартовая цель `6000`;
- текущий день не участвует в собственной цели;
- `dailyGoalPolicy` объясняет baseline и параметры политики; при чётном числе дней `baselineSteps` может содержать `.5`;
- ENERGY, expedition и progression глобальны для пользователя;
- неизвестный пользователь получает zero-state и starter content;
- `GET` не выполняет `INSERT` или `UPDATE`.

## `POST /api/v1/activity/sync`

Принимает cumulative authoritative total, сохраняет дневной high-watermark и начисляет ENERGY через ledger.

```http
X-User-Id: demo-user-1
X-Device-Id: demo-device-1
```

Request:

```json
{
  "localDate": "2026-07-26",
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
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Формула:

```text
energyGranted = floor(newAcceptedTotal / 100)
              - floor(previousAcceptedTotal / 100)
```

`riskStatus`:

```text
ACCEPTED
NO_NEW_ACTIVITY
TOTAL_DECREASED
```

Повтор одного key и payload возвращает исходный response. Тот же key с другим business payload возвращает `409 IDEMPOTENCY_CONFLICT`.

## `POST /api/v1/expeditions/{expeditionId}/advance`

Тратит ENERGY на persistent progress экспедиции.

```http
X-User-Id: demo-user-1
```

Request:

```json
{
  "energyToSpend": 30,
  "idempotencyKey": "starter-expedition-v1-advance-1"
}
```

Response после достижения узла:

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
    "summary": "Маяк отвечает повторяющимся импульсом.",
    "status": "READY"
  },
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Правила:

- `energyToSpend > 0`;
- amount не превышает остаток до узла;
- partial advance разрешён;
- wallet не становится отрицательным;
- после `EVENT_READY` новый advance возвращает `409 EXPEDITION_STATE_CONFLICT`;
- debit, ledger, progress и response сохраняются одной транзакцией.

## `POST /api/v1/events/{eventId}/resolve`

Разрешает открытое событие одним из server-owned вариантов и атомарно применяет progression reward.

```http
X-User-Id: demo-user-1
```

Request:

```json
{
  "choiceId": "analyze-signal",
  "idempotencyKey": "signal-source-v1-resolution-1"
}
```

Доступные choice для `signal-source-v1`:

```text
analyze-signal  → +40 pilot XP, +5 pet bond
trust-spark     → +20 pilot XP, +15 pet bond
```

Response:

```json
{
  "contentVersion": "starter-v1",
  "expeditionId": "starter-expedition-v1",
  "expeditionStatus": "COMPLETED",
  "expeditionVersion": 2,
  "eventId": "signal-source-v1",
  "eventTitle": "Источник сигнала",
  "status": "RESOLVED",
  "choiceId": "analyze-signal",
  "choiceTitle": "Проанализировать сигнал",
  "outcomeTitle": "Карта импульсов",
  "outcomeSummary": "Навигатор выделил безопасный ритм доступа.",
  "pilot": {
    "pilotId": "navigator-v1",
    "name": "Навигатор",
    "level": 1,
    "experienceGained": 40,
    "currentExperience": 60,
    "nextLevelExperience": 100,
    "version": 1
  },
  "pet": {
    "petId": "spark-v1",
    "name": "Искра",
    "level": 1,
    "bondGained": 5,
    "bond": 15,
    "version": 1
  },
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Правила:

- event должен быть фактически открыт и expedition должна иметь `EVENT_READY`;
- `choiceId` выбирается из server-owned definition;
- после успеха expedition становится `COMPLETED`;
- тот же key и payload возвращает исходный response без второй награды;
- тот же key с другим choice возвращает `409 IDEMPOTENCY_CONFLICT`;
- неизвестный choice возвращает `400 VALIDATION_ERROR`;
- повторное resolution возвращает `409 EVENT_STATE_CONFLICT`;
- expedition completion, pilot XP, pet bond и processed response фиксируются одной транзакцией.

## Ошибки

Базовый формат:

```json
{
  "code": "VALIDATION_ERROR | NOT_FOUND | CONFLICT | INTERNAL_ERROR",
  "message": "человекочитаемое описание",
  "details": {
    "field": "idempotencyKey"
  },
  "traceId": "uuid"
}
```

Используемые domain code:

```text
IDEMPOTENCY_CONFLICT
INSUFFICIENT_ENERGY
EXPEDITION_STATE_CONFLICT
EVENT_STATE_CONFLICT
VALIDATION_ERROR
NOT_FOUND
```

## Следующие endpoint-ы

```text
GET  /api/v1/content/bootstrap
POST /api/v1/pets/{petId}/upgrade
```
