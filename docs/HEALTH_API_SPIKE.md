# Platform Health API spike

- **Статус:** implementation/build complete, physical-device validation pending
- **Дата:** 2026-07-26
- **Связанный issue:** #19

## 1. Цель

Подключить реальные шаги iOS и Android к уже стабильному activity-sync контракту, не перенося расчёт награды на клиент и не связывая UI напрямую с конкретным plugin API.

Целевой путь:

```text
HealthKit / Health Connect
→ StepSource
→ ActivitySyncCoordinator
→ POST /api/v1/activity/sync
→ server delta + ENERGY ledger
→ GET /api/v1/home
```

## 2. Принятое решение

Для первого platform spike используется пакет `health` 13.3.1:

- Apple HealthKit на iOS;
- Google Health Connect на Android;
- единый foreground API чтения cumulative steps;
- собственная доменная абстракция `StepSource` остаётся выше пакета.

Дополнительно используются:

- `permission_handler` для Android `ACTIVITY_RECOGNITION`;
- `flutter_timezone` для IANA timezone.

Если пакет окажется нестабилен на физических устройствах или станет блокировать нужную антифрод/metadata-функциональность, его можно заменить нативными Swift/Kotlin bridge без изменения `ActivityApiClient` и backend-контракта.

## 3. Версии платформ

| Платформа | Текущая настройка | Примечание |
|---|---:|---|
| iOS | deployment target 14.0 | обусловлено HealthKit adapter/pod |
| Android | minSdk 26 | доступность Health Connect дополнительно проверяется runtime |
| Flutter | 3.44.7 | закреплено в CI |
| Dart | 3.8+ | требуется зависимостями platform source |

Минимальная версия проекта не означает, что Health Connect гарантированно присутствует на каждом устройстве. Source отдельно различает `available`, `providerUpdateRequired` и `unavailable`.

## 4. Запрашиваемые данные

Единственный health data type:

```text
STEPS — READ
```

Период чтения:

```text
локальная полночь устройства → текущее локальное время
```

В `StepReading` попадают:

```text
authoritativeTotal
localDate
IANA timeZone
syncCursor
```

Backend получает cumulative total и самостоятельно вычисляет положительную дельту и ENERGY.

## 5. Конфиденциальность

Не запрашиваются и не отправляются:

- сердечный ритм;
- сон;
- вес;
- тренировки и маршруты;
- геолокация;
- медицинские записи;
- контакты;
- рекламные идентификаторы.

Сырые HealthKit/Health Connect samples не отправляются. На server уходит только агрегат текущего дня вместе с локальной датой и часовым поясом.

Перед store release ещё требуются:

- публичная privacy policy;
- Google Play Health Connect declaration/Data Safety;
- App Store privacy disclosures;
- финальный privacy-policy link из Android rationale activity;
- проверка локализованных permission descriptions.

## 6. Идемпотентность

`ActivitySyncCoordinator` хранит pending reading и key в памяти:

```text
тот же reading после ошибки
→ тот же idempotency key

reading изменился
→ новый key

успешный response
→ pending key очищается
```

Если приложение завершилось между отправкой и response, exact key не переживает процесс. При этом backend high-watermark всё равно не выдаст ENERGY выше нового cumulative total. Постоянная offline command queue остаётся отдельной задачей.

## 7. Manual entry и anti-fraud

Вызов cumulative steps использует:

```text
includeManualEntries = false
```

Это best-effort сигнал адаптера. Он не является достаточной защитой:

- данные могут приходить от нескольких приложений и устройств;
- platform metadata неодинакова на iOS и Android;
- источник может изменить или удалить записи;
- модифицированное устройство остаётся отдельным риском.

Действующие серверные защиты сохраняются:

- монотонный daily high-watermark;
- отсутствие отрицательной награды;
- idempotency;
- user-level serialization;
- server-owned reward formula.

Перед beta понадобятся source metadata, risk score и device attestation.

## 8. Ошибки

Стабильные failure-категории mobile:

```text
unsupportedPlatform
providerUpdateRequired
providerUnavailable
activityRecognitionDenied
activityRecognitionSettingsRequired
activityRecognitionRestricted
authorizationDenied
protectedDataUnavailable
timeZoneUnavailable
readFailed
```

Home screen не заменяется ошибочным zero-state. Ошибка sync показывается отдельно, а последнее прочитанное серверное состояние остаётся на экране.

## 9. Нативная конфигурация

### Android

- `READ_STEPS`;
- `ACTIVITY_RECOGNITION`;
- Health Connect package query;
- permission-rationale intent;
- permission-usage activity;
- `FlutterFragmentActivity`;
- debug-only cleartext HTTP для локального backend.

### iOS

- HealthKit entitlement;
- `NSHealthShareUsageDescription`;
- iOS 14 deployment target;
- CocoaPods `use_frameworks!`, необходимый текущему Swift/Objective-C bridge пакета `health`;
- Flutter plugin Swift Package Manager отключён для данного проекта, пока `health` не поддерживает его.

## 10. Автоматически проверено

| Проверка | Статус |
|---|---|
| Dart format | пройдено |
| Flutter analyze | пройдено |
| Flutter unit/widget tests | пройдено |
| Android debug APK | собрано в CI |
| iOS Simulator debug app | собрано в CI |
| Backend regression suite | пройдено |
| PostgreSQL integration suite | пройдено |

Unit tests проверяют local-day boundary, timezone, null total, provider availability, permissions и защищённые iOS-данные.

## 11. Что автоматическая проверка не доказывает

CI build не подтверждает фактическое чтение данных HealthKit/Health Connect. Нужен ручной device matrix:

| Сценарий | Статус |
|---|---|
| iPhone, только встроенный источник шагов | не проверено |
| iPhone + Apple Watch | не проверено |
| Android + Health Connect | не проверено |
| Android + несколько data providers | не проверено |
| ручной ввод | не проверено |
| удаление/коррекция записи | не проверено |
| отзыв permissions | не проверено |
| смена timezone | не проверено |
| переход через полночь | не проверено |
| расход батареи | не проверено |

До прохождения этой матрицы Milestone 1 нельзя считать полностью закрытым.

## 12. Следующие действия

1. Проверить iPhone и Android на физических устройствах.
2. Зафиксировать фактическую семантику отказа/нулевых данных на iOS.
3. Проверить телефон + часы и несколько Android providers.
4. Решить, нужны ли source buckets/metadata в backend contract.
5. Добавить persistent mobile command queue.
6. Добавить attestation и серверный risk score.
7. После подтверждения foreground-flow исследовать background delivery.
