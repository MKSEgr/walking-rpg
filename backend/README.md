# Walking RPG Backend

Java/Spring Boot backend первоначального проекта.

## Стек

- Java 21
- Spring Boot 4.1.x
- Spring MVC
- Bean Validation
- Spring JDBC
- PostgreSQL 17
- Flyway
- Testcontainers
- Actuator
- Maven Wrapper

Activity sync хранит принятый total, версию состояния и idempotent response в PostgreSQL. Для запросов одной пары user/device используется PostgreSQL advisory transaction lock: конкурирующие sync сериализуются не только внутри одного Java-процесса, но и между backend-инстансами.

## Локальный запуск

Из корня репозитория запустить PostgreSQL:

```bash
docker compose up -d postgres
```

Затем:

```bash
cd backend
./mvnw spring-boot:run
```

Windows:

```powershell
docker compose up -d postgres
cd backend
.\mvnw.cmd spring-boot:run
```

Стандартные параметры подключения:

```text
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/walking_rpg
SPRING_DATASOURCE_USERNAME=walking_rpg
SPRING_DATASOURCE_PASSWORD=walking_rpg_local
```

Flyway автоматически применяет миграции из `src/main/resources/db/migration`.

## Тесты

```bash
./mvnw verify
```

Интеграционные тесты используют Testcontainers и требуют доступный Docker daemon. Они поднимают чистый PostgreSQL, применяют Flyway и проверяют постоянную idempotency и сериализацию конкурентных запросов.

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

## Что сохраняется

```text
app_user                  — временная техническая identity пользователя
app_device                — устройство пользователя
activity_sync_state       — последний принятый total и версия по локальному дню
processed_activity_sync   — fingerprint запроса и неизменяемый idempotent response
```

Сырые bucket-ы, attestation и sync cursor в БД пока не сохраняются. Для проверки повторного ключа хранится SHA-256 fingerprint нормализованной команды.

## Текущие ограничения

- заголовки пользователя и устройства временные;
- attestation пока не проверяется;
- энергия не записывается в экономический ledger;
- для `processed_activity_sync` ещё не реализована retention-политика;
- mobile пока не вызывает endpoint;
- модель `app_user`/`app_device` техническая и будет заменена или расширена при появлении аутентификации.

Следующая продуктовая задача:

```text
persistent activity sync → economy ledger → энергия экспедиции → один игровой узел
```
