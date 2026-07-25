# Walking RPG Backend

Java/Spring Boot shell для первоначального проекта.

## Стек

- Java 21
- Spring Boot 4.1.x
- Spring MVC
- Bean Validation
- Actuator
- Maven Wrapper

PostgreSQL и Flyway подключаются в первом persistent vertical slice, когда будет согласована модель activity sync. Это сделано намеренно: backend сейчас запускается без обязательной внешней инфраструктуры.

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
GET /actuator/health
GET /api/v1/system/info
GET /api/v1/home/demo
```

## Следующая задача

Добавить первый реальный vertical slice `activity`:

```text
contract → migration → repository → delta calculation → ledger → tests → mobile integration
```
