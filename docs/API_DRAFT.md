# API draft

Документ содержит направление, а не финальный OpenAPI-контракт.

## Текущие scaffold endpoint-ы

### `GET /api/v1/system/info`

Проверка запущенного backend.

### `GET /api/v1/home/demo`

Демонстрационное состояние главного экрана. Не является production-моделью.

### `POST /api/v1/activity/sync`

Первый технический срез синхронизации активности. Контракт, расчёт, PostgreSQL persistence и начисление энергии через economy ledger реализованы. Accepted state, wallet credit, ledger entry и idempotent response сохраняются одной транзакцией; конкурирующие запросы пользователя сериализуются user-level advisory lock.

До появления аутентификации и регистрации устройств используются временные обязательные заголовки:

```text
X-User-Id: demo-user-1
X-Device-Id: demo-device-1
```

После появления security слоя `X-User-Id` заменяется authenticated principal, а `X-Device-Id` — идентификатором зарегистрированного устройства.

#### Request

```json
{
  "localDate": "2026-07-25",
  "timeZone": "Europe/Berlin",
  "authoritativeTotal": 6842,
  "buckets": [
    {
      "from": "2026-07-25T08:00:00Z",
      "to": "2026-07-25T09:00:00Z",
      "steps": 412
    }
  ],
  "syncCursor": "opaque-cursor",
  "idempotencyKey": "device-date-sequence",
  "attestation": null
}
```

Правила:

- `authoritativeTotal >= 0`;
- `timeZone` должен быть валидным IANA Zone ID;
- в bucket `from < to` и `steps >= 0`;
- максимум 96 bucket-ов на запрос;
- одинаковый `idempotencyKey` в рамках одного пользователя и устройства должен сопровождаться идентичным business payload;
- attestation может быть перевыпущен при повторе, не входит в business fingerprint и в будущем проверяется отдельно для каждого запроса;
- reward high-watermark хранится на пользователя и локальный день, а не отдельно на каждое устройство;
- cumulative total разных устройств не суммируется; сервер принимает только рост общего user-level total;
- уменьшение total не создаёт отрицательную награду;
- положительная `energyGranted` зачисляется только через economy ledger;
- zero/decreased sync не создаёт ledger entry.

#### Response

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

Поля экономики:

- `energyGranted` — сколько энергии начислено именно этой операцией;
- `energyBalanceAfter` — баланс ENERGY сразу после этой операции;
- `economyVersion` — версия кошелька после этой операции. Версия увеличивается только при появлении ledger entry.

`riskStatus` на текущем этапе:

```text
ACCEPTED          — принят положительный прирост;
NO_NEW_ACTIVITY   — total не изменился;
TOTAL_DECREASED   — новый total меньше ранее принятого, состояние не уменьшено.
```

Энергия рассчитывается по накопительным порогам, а не простым округлением каждой отдельной дельты:

```text
energyGranted = floor(newAcceptedTotal / 100)
              - floor(previousAcceptedTotal / 100)
```

#### Идемпотентный повтор

Повтор идентичной бизнес-команды с тем же ключом возвращает сохранённый response, включая исходные `stateVersion`, `serverTime`, `energyBalanceAfter` и `economyVersion`. Поэтому `energyBalanceAfter` является snapshot-ом баланса после исходной операции, а не принудительным чтением самого нового баланса на момент повтора.

Повтор ключа с другим payload:

```http
409 Conflict
```

```json
{
  "code": "IDEMPOTENCY_CONFLICT",
  "message": "idempotencyKey уже использован для другого запроса",
  "details": {
    "field": "idempotencyKey"
  },
  "traceId": "f508bf6a-73e5-4aa2-88f5-6b712a571dd6"
}
```

## Планируемые endpoint-ы first playable

```text
GET  /api/v1/home
POST /api/v1/expeditions/{expeditionId}/start
POST /api/v1/expeditions/{expeditionId}/advance
POST /api/v1/events/{eventId}/resolve
POST /api/v1/pets/{petId}/upgrade
GET  /api/v1/content/bootstrap
```

## Общие правила

- JSON поля — camelCase;
- даты/время — ISO-8601;
- все команды изменения поддерживают idempotency;
- клиент не передаёт итоговую награду;
- баланс меняется только через ledger;
- ошибки имеют стабильный `code`, человекочитаемый `message`, `details` и `traceId`;
- версионирование API начинается с `/api/v1`;
- destructive изменения требуют новой версии или миграционного периода.

## Базовый формат ошибки

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Запрос не прошёл валидацию",
  "details": {
    "authoritativeTotal": "must be greater than or equal to 0"
  },
  "traceId": "f508bf6a-73e5-4aa2-88f5-6b712a571dd6"
}
```
