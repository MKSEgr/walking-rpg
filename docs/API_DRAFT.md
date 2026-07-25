# API draft

Документ содержит направление, а не финальный OpenAPI-контракт.

## Текущие scaffold endpoint-ы

### `GET /api/v1/system/info`

Проверка запущенного backend.

### `GET /api/v1/home/demo`

Демонстрационное состояние главного экрана. Не является production-моделью.

## Планируемые endpoint-ы first playable

```text
POST /api/v1/activity/sync
GET  /api/v1/home
POST /api/v1/expeditions/{expeditionId}/start
POST /api/v1/expeditions/{expeditionId}/advance
POST /api/v1/events/{eventId}/resolve
POST /api/v1/pets/{petId}/upgrade
GET  /api/v1/content/bootstrap
```

## Черновик activity sync

### Request

```json
{
  "localDate": "2026-07-25",
  "timeZone": "Europe/Moscow",
  "authoritativeTotal": 6842,
  "buckets": [],
  "syncCursor": "opaque-cursor",
  "idempotencyKey": "device-date-sequence",
  "attestation": null
}
```

### Response

```json
{
  "acceptedTotal": 6842,
  "acceptedDelta": 842,
  "energyGranted": 8,
  "riskStatus": "ACCEPTED",
  "stateVersion": 17,
  "serverTime": "2026-07-25T12:00:00Z"
}
```

## Общие правила

- JSON поля — camelCase;
- даты/время — ISO-8601;
- все команды изменения поддерживают idempotency;
- клиент не передаёт итоговую награду;
- ошибки имеют стабильный `code`, человекочитаемый `message`, `details` и `traceId`;
- версионирование API начинается с `/api/v1`;
- destructive изменения требуют новой версии или миграционного периода.

## Черновик ошибки

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Некорректное значение authoritativeTotal",
  "details": {
    "field": "authoritativeTotal"
  },
  "traceId": "f508bf6a-73e5-4aa2-88f5-6b712a571dd6"
}
```
