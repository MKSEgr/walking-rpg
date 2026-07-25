# Walking RPG Backend

Java/Spring Boot backend первоначального проекта.

## Стек

- Java 21
- Spring Boot 4.1.x
- Spring MVC
- Bean Validation
- Actuator
- Maven Wrapper

PostgreSQL и Flyway подключаются в persistent activity-sync vertical slice. Первый контракт и доменная логика активности намеренно работают через in-memory repository: это позволяет проверить инварианты до фиксации схемы данных.

## Запуск

```bash
./mvnw spring-boot:run
```

Windows:

```powershell
.\mvnw.cmd spring-boot:run
```

## Тесты

```bash
./mvnw test
```

## Endpoint-ы

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home/demo
POST /api/v1/activity/sync
```

Пример синхронизации:

```bash
curl -X POST http://localhost:8080/api/v1/activity/sync \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: demo-user-1' \
  -H 'X-Device-Id: demo-device-1' \
  -d '{
    "localDate": "2026-07-25",
    "timeZone": "Europe/Berlin",
    "authoritativeTotal": 6842,
    "buckets": [],
    "syncCursor": "cursor-1",
    "idempotencyKey": "demo-device-1-2026-07-25-1",
    "attestation": null
  }'
```

## Ограничение текущего activity spike

- состояние теряется после перезапуска;
- реализация рассчитана на один backend-процесс;
- заголовки пользователя и устройства временные;
- attestation пока не проверяется;
- энергия не записывается в ledger.

Следующая задача:

```text
PostgreSQL + Flyway → activity_ingestion + sync_state → транзакция → persistent idempotency
```
