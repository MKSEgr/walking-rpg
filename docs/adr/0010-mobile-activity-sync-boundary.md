# ADR 0010: разделить platform StepSource и backend ActivityApiClient

- **Статус:** Accepted for Health API preparation
- **Дата:** 2026-07-26

## Контекст

Backend activity contract уже стабилен, но Flutter до сих пор не отправлял шаги. Одновременно ещё не выбрана окончательная реализация Apple Health / Health Connect.

Прямая привязка UI к конкретному Flutter plugin создала бы сразу несколько рисков:

- сетевой контракт смешивается с permissions и platform API;
- тесты требуют нативного окружения;
- смена plugin затрагивает экран и HTTP-клиент;
- невозможно отдельно проверить mobile → backend flow.

## Решение

Mobile разделяется на три части:

```text
StepSource
  получает cumulative authoritative reading

ActivityApiClient
  отправляет reading в POST /api/v1/activity/sync

ActivitySyncCoordinator
  связывает source и client, управляет retry key
```

### StepReading

Reading содержит:

```text
authoritativeTotal
localDate
timeZone (IANA Zone ID)
syncCursor (optional)
```

Он не содержит рассчитанную delta или reward.

### Idempotency retry

Coordinator хранит pending reading и key:

- если sender завершился ошибкой, повтор того же reading использует тот же key;
- если reading изменился, создаётся новый key;
- после успешной команды pending state очищается;
- authoritative high-watermark backend остаётся второй линией защиты.

### Development source

До platform spike вводится `DevelopmentStepSource`.

Он:

- включается только `ENABLE_DEMO_ACTIVITY_SYNC=true`;
- получает total и IANA zone через `dart-define`;
- отображает явно тестовую кнопку;
- не включается в обычном запуске;
- не считается Health API implementation.

### UI state

После успешного sync mobile не изменяет шаги и баланс локально. Он повторно вызывает `GET /home`, сохраняя server-authoritative модель.

## Последствия

Плюсы:

- HTTP integration тестируется до нативного spike;
- HealthKit/Health Connect заменяют только `StepSource`;
- network retry сохраняет exact idempotency;
- fake activity не маскируется под production data.

Ограничения:

- development total меняется только через новый запуск;
- нет permissions/background delivery;
- нет offline queue;
- IANA zone пока передаётся configuration, а не platform bridge.
