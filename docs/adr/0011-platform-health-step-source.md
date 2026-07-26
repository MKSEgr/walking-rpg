# ADR 0011: platform health source за доменной границей StepSource

- **Статус:** Accepted for platform spike
- **Дата:** 2026-07-26

## Контекст

Backend уже принимает cumulative step total, обеспечивает idempotency, хранит daily high-watermark и начисляет ENERGY через ledger. Flutter-клиент уже имеет `StepSource`, development source и стабильный `ActivityApiClient`.

Следующая задача — получить реальные шаги с iOS и Android. Возможные варианты:

1. сразу написать собственные Swift/Kotlin bridges;
2. напрямую использовать plugin во всех presentation/application слоях;
3. использовать кроссплатформенный adapter под существующей доменной границей.

Для команды из двух участников важно быстро проверить platform risks и не привязать продуктовую логику к стороннему API.

## Решение

1. Для foreground spike используется `health` 13.3.1.
2. Пакет инкапсулирован в `HealthGateway`.
3. `PlatformHealthStepSource` реализует существующий `StepSource`.
4. Android permission вынесен в `ActivityRecognitionGateway`.
5. IANA timezone вынесена в `DeviceTimeZoneProvider`.
6. В обычном Android/iOS запуске platform source используется по умолчанию.
7. `DevelopmentStepSource` доступен только при `ENABLE_DEMO_ACTIVITY_SYNC=true`.
8. Читается только `STEPS` с доступом READ.
9. Чтение выполняется от локальной полуночи до текущего времени.
10. Backend остаётся единственным владельцем accepted delta, ENERGY и risk decision.
11. После sync mobile перечитывает `GET /home`, не применяя optimistic update.
12. Android/iOS host-проекты фиксируются в репозитории.
13. CI собирает debug APK и iOS Simulator app.

## Нативные решения

### Android

- `minSdk = 26`;
- runtime Health Connect availability;
- `READ_STEPS` и `ACTIVITY_RECOGNITION`;
- `FlutterFragmentActivity` для Activity Result API;
- отдельный rationale/permission usage entry point.

### iOS

- deployment target 14.0;
- HealthKit capability;
- read usage description;
- CocoaPods framework integration.

Текущая версия `health` содержит Swift implementation с Objective-C registration bridge. Для доступности generated Swift header Podfile использует `use_frameworks!`. Swift Package Manager для Flutter plugins отключён, пока пакет не поддерживает его.

## Почему не собственные native bridges сейчас

Собственный bridge даст максимальный контроль над metadata, background delivery и error semantics, но потребует параллельно проектировать и тестировать две платформенные реализации до подтверждения базового foreground-flow.

Текущий adapter позволяет проверить:

- разрешения;
- доступность Health Connect;
- cumulative steps;
- timezone/day boundary;
- build/linking;
- интеграцию с существующим backend.

Замена adapter-а не затронет `ActivitySyncCoordinator`, `ActivityApiClient`, UI-команду или backend contract.

## Почему не plugin types в домене

Типы `HealthDataType`, `HealthDataAccess` и platform exceptions не выходят за data-слой. Это предотвращает:

- зависимость домена от конкретного package;
- распространение платформенных enum по UI;
- необходимость переписывать тесты при смене adapter-а;
- клиентский расчёт награды.

## Последствия

Плюсы:

- один application flow для iOS/Android;
- существующая retry-idempotency сохранена;
- минимальный набор health permissions;
- package можно заменить за gateway;
- Android и iOS builds проверяются CI;
- development source остаётся воспроизводимым.

Минусы и ограничения:

- фактическое поведение ещё нужно проверить на устройствах;
- iOS read denial и отсутствие данных могут быть неразличимы;
- manual-entry filtering не является полной антифрод-защитой;
- pending idempotency key пока не переживает restart;
- background delivery отсутствует;
- store privacy flow ещё не готов;
- `use_frameworks!` влияет на iOS dependency integration.

## Условия пересмотра

Переходим к собственным Swift/Kotlin bridges, если выполняется хотя бы одно условие:

- package не даёт нужные source metadata;
- foreground reading нестабилен на целевых устройствах;
- background delivery невозможно реализовать корректно;
- release cadence package блокирует новые версии iOS/Android;
- platform-specific anti-fraud требует недоступных API;
- build/linking становится систематически нестабильным.
