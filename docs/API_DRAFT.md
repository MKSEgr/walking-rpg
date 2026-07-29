# API draft

Документ фиксирует работающие MVP-контракты, но пока не заменяет полноценную OpenAPI-спецификацию.

## Общие правила

- namespace: `/api/v1`;
- JSON-поля: camelCase;
- даты/время: ISO-8601;
- команды изменения поддерживают idempotency;
- клиент не передаёт рассчитанную награду, баланс, progress или progression;
- ошибки имеют `code`, `message`, `details`, `traceId`;
- production API использует `Authorization: Bearer <access-token>`; `userId`, actor и activity device identity вычисляются backend-ом из authenticated context;
- локальные `X-User-Id` / `X-Device-Id` разрешены только в явном профиле `local` с `dev-header`; production-профиль их игнорирует;
- пользовательские endpoint-ы требуют `ROLE_USER`, `/api/v1/admin/**` требует `ROLE_ADMIN`.

## `GET /api/v1/system/info`

Проверка запущенного backend.

## `GET /api/v1/account/export`

Возвращает полный JSON-экспорт данных текущего authenticated subject. Mobile
создаёт временный JSON-файл, передаёт его через системный share sheet и удаляет
локальную staging-копию после закрытия sheet. Постоянное место сохранения
выбирает пользователь в системном интерфейсе.

```http
Authorization: Bearer <access-token>
Accept: application/json
```

## `POST /api/v1/account/deletion-requests`

Синхронно удаляет игровые данные authenticated subject и возвращает постоянную
квитанцию. Перед запросом mobile выполняет интерактивную OIDC-проверку той же
учётной записи с `prompt=login` и `max_age=0`, затем двухэтапное
пользовательское подтверждение.

```http
Authorization: Bearer <fresh-access-token>
Idempotency-Key: account-delete-7a35d4bbf64f4e7ca441e59b61eb9ec4
Content-Type: application/json
```

```json
{
  "confirmation": "DELETE"
}
```

```json
{
  "receiptId": "11111111-1111-1111-1111-111111111111",
  "status": "COMPLETED",
  "requestedAt": "2026-07-29T05:00:00Z",
  "completedAt": "2026-07-29T05:00:00Z",
  "replayed": false
}
```

Backend принимает destructive request только если подписанный access token
содержит `auth_time` не старше
`ACCOUNT_DELETION_MAX_AUTH_AGE` (по умолчанию `PT5M`). Отсутствующий,
некорректный или устаревший claim возвращает
`403 FRESH_AUTHENTICATION_REQUIRED`. Production IdP обязан включать
стандартный OIDC `auth_time` в access token.

Повтор после потери ответа возвращает ту же квитанцию с `replayed=true`, в том
числе после перезапуска клиента. Backend хранит только SHA-256 subject и
idempotency key, UUID квитанции и timestamps; raw OIDC subject в квитанции не
сохраняется.

После создания квитанции остальные authenticated endpoints для этого subject
возвращают `410 ACCOUNT_DELETED`, поэтому старый Bearer token не может
пересоздать игровой аккаунт. Сам deletion endpoint остаётся доступен для
idempotent replay квитанции. Bearer transport воспринимает этот код как
окончательное удаление и запускает fail-closed локальную очистку без refresh.

## `GET /api/v1/home/demo`

Явное демонстрационное состояние. Production mobile не использует его как silent fallback.

## `GET /api/v1/home?localDate=YYYY-MM-DD`

Возвращает актуальный read-model главного экрана.

```http
Authorization: Bearer <access-token>
```

После завершения второго события response содержит:

```json
{
  "localDate": "2026-07-26",
  "timeZone": "Europe/Berlin",
  "dailySteps": 10000,
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
  "availableEnergy": 25,
  "activityStateVersion": 1,
  "economyVersion": 3,
  "lastActivitySyncAt": "2026-07-26T06:55:00Z",
  "serverTime": "2026-07-26T07:00:00Z",
  "contentVersion": "starter-v2",
  "pilot": {
    "name": "Навигатор",
    "level": 1,
    "currentExperience": 90,
    "nextLevelExperience": 100,
    "specialization": "Не выбрана"
  },
  "pet": {
    "name": "Искра",
    "species": "Люмин",
    "level": 1,
    "bond": 23,
    "trait": "Чуткий разведчик"
  },
  "inventory": [
    {
      "itemId": "lumen-shard",
      "name": "Люминовый осколок",
      "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
      "quantity": 2,
      "version": 1
    }
  ],
  "expedition": {
    "expeditionId": "starter-expedition-v1",
    "name": "Сигнал из туманного сектора",
    "currentNodeId": "lumen-gate",
    "currentNode": "Люминовые ворота",
    "progress": 45,
    "requiredEnergy": 45,
    "status": "COMPLETED",
    "version": 4,
    "unlockedEvent": {
      "eventId": "echo-vault-v1",
      "title": "Хранилище эха",
      "summary": "За воротами найден архив маршрутов.",
      "status": "RESOLVED",
      "selectedChoiceId": "stabilize-core",
      "selectedChoiceTitle": "Стабилизировать ядро",
      "outcomeTitle": "Стабильный резонанс",
      "outcomeSummary": "Ядро перестало разрушаться.",
      "materialReward": {
        "itemId": "lumen-shard",
        "itemName": "Люминовый осколок",
        "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
        "quantityGained": 2,
        "quantityAfter": 2,
        "version": 1
      }
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
- ENERGY, expedition, progression и inventory глобальны для пользователя;
- неизвестный пользователь получает zero-state и starter content;
- `inventory[]` содержит актуальный stack; `materialReward` — immutable snapshot последнего разрешённого события;
- `GET` не выполняет `INSERT` или `UPDATE`.

## `POST /api/v1/activity/sync`

Принимает cumulative authoritative total, сохраняет дневной high-watermark и начисляет ENERGY через ledger.

```http
Authorization: Bearer <access-token>
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
Authorization: Bearer <access-token>
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
  "contentVersion": "starter-v2",
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
- после первого event resolution тот же endpoint продвигает второй узел `lumen-gate` с порогом 45;
- debit, ledger, progress и response сохраняются одной транзакцией.

## `POST /api/v1/events/{eventId}/resolve`

Разрешает открытое событие одним из server-owned вариантов и атомарно применяет progression/material reward.

```http
Authorization: Bearer <access-token>
```

Request:

```json
{
  "choiceId": "stabilize-core",
  "idempotencyKey": "echo-vault-v1-resolution-1"
}
```

Starter content v2:

```text
signal-source-v1
  analyze-signal  → +40 pilot XP, +5 pet bond, переход к lumen-gate
  trust-spark     → +20 pilot XP, +15 pet bond, переход к lumen-gate

echo-vault-v1
  stabilize-core  → +30 pilot XP, +8 pet bond, +2 lumen-shard, COMPLETED
  follow-echo     → +20 pilot XP, +18 pet bond, +1 echo-thread, COMPLETED
```

Response второго события:

```json
{
  "contentVersion": "starter-v2",
  "expeditionId": "starter-expedition-v1",
  "expeditionStatus": "COMPLETED",
  "expeditionVersion": 4,
  "eventId": "echo-vault-v1",
  "eventTitle": "Хранилище эха",
  "status": "RESOLVED",
  "choiceId": "stabilize-core",
  "choiceTitle": "Стабилизировать ядро",
  "outcomeTitle": "Стабильный резонанс",
  "outcomeSummary": "Ядро перестало разрушаться, а два люминовых осколка сохранили его энергию.",
  "pilot": {
    "pilotId": "navigator-v1",
    "name": "Навигатор",
    "level": 1,
    "experienceGained": 30,
    "currentExperience": 90,
    "nextLevelExperience": 100,
    "version": 2
  },
  "pet": {
    "petId": "spark-v1",
    "name": "Искра",
    "level": 1,
    "bondGained": 8,
    "bond": 23,
    "version": 2
  },
  "material": {
    "itemId": "lumen-shard",
    "name": "Люминовый осколок",
    "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
    "quantityGained": 2,
    "quantityAfter": 2,
    "version": 1
  },
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Для первого события `material = null`, а `expeditionStatus = IN_PROGRESS`, потому что команда открывает второй узел.

Правила:

- event должен быть фактически открыт и expedition должна иметь `EVENT_READY`;
- `choiceId` выбирается из server-owned definition соответствующего `eventId`;
- первый event resolution переводит progress на второй узел, второй — в `COMPLETED`;
- тот же key и payload возвращает исходный response без второй награды;
- тот же key с другим choice возвращает `409 IDEMPOTENCY_CONFLICT`;
- неизвестный choice возвращает `400 VALIDATION_ERROR`;
- повторное resolution новым key возвращает `409 EVENT_STATE_CONFLICT`;
- один inventory source не может выдать другой item или quantity;
- expedition transition/completion, pilot XP, pet bond, inventory stack/ledger и processed response фиксируются одной транзакцией.

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
INVENTORY_LEDGER_CONFLICT
VALIDATION_ERROR
NOT_FOUND
```

## Следующие endpoint-ы

```text
GET  /api/v1/content/bootstrap
POST /api/v1/pets/{petId}/upgrade
```
