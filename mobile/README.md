# Walking RPG Mobile

Flutter-клиент walking-RPG. Android- и iOS-host проекты зафиксированы в репозитории.

## Стек

- Flutter 3.44.7;
- Dart 3.8+;
- `health` 13.3.1;
- `permission_handler` 12.0.3;
- `flutter_timezone` 5.1.0;
- нативные Android/iOS host-проекты;
- dependency-light REST transport на `dart:io`.

## Источник активности

Доменная граница:

```text
StepSource
  ├── PlatformHealthStepSource
  │     ├── Apple HealthKit
  │     └── Google Health Connect
  └── DevelopmentStepSource
```

`StepSource` возвращает только исходное чтение:

```text
authoritativeTotal
localDate
timeZone
syncCursor
```

Он не вычисляет `acceptedDelta`, ENERGY или баланс. Эти значения принадлежат Java backend.

## Реальный foreground-flow

1. Пользователь нажимает **«Синхронизировать шаги»**.
2. Android проверяет доступность Health Connect и разрешение `ACTIVITY_RECOGNITION`; iOS использует HealthKit.
3. Запрашивается read-only доступ к `STEPS`.
4. Читается суммарное количество шагов от локальной полуночи до текущего времени.
5. Определяется IANA timezone устройства.
6. `ActivitySyncCoordinator` отправляет чтение в `POST /api/v1/activity/sync`.
7. После успеха приложение полностью перечитывает `GET /api/v1/home`.

При повторе того же чтения после сетевой ошибки coordinator повторно использует тот же idempotency key в пределах жизни процесса. Изменившееся чтение получает новый key.

## Минимальные платформенные настройки

### Android

- project `minSdk = 26`;
- фактическая доступность Health Connect проверяется runtime;
- `READ_STEPS`;
- `ACTIVITY_RECOGNITION`;
- `MainActivity` наследуется от `FlutterFragmentActivity`;
- настроены Health Connect package query, rationale intent и permission-usage activity;
- cleartext HTTP разрешён только в debug manifest для локального backend.

На устройствах, где Health Connect отсутствует или требует обновления, приложение возвращает отдельное пользовательское сообщение и не ломает главный экран.

### iOS

- deployment target iOS 14.0;
- HealthKit capability;
- `NSHealthShareUsageDescription`;
- read-only authorization;
- CocoaPods `use_frameworks!` для Swift/Objective-C bridge пакета `health`;
- Swift Package Manager для Flutter plugins отключён в этом проекте, пока пакет `health` его не поддерживает.

HealthKit может не раскрывать приложению факт отказа в чтении как отдельный надёжный статус. Нулевое чтение поэтому не трактуется как доказательство наличия или отсутствия разрешения.

## Запуск

Android Emulator:

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=android-emulator-1
```

iOS Simulator:

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=ios-simulator-1
```

Для чтения настоящих данных нужен физический телефон с настроенным HealthKit/Health Connect. Simulator CI подтверждает компиляцию и linking, но не заменяет device-проверку.

На физическом устройстве задаётся LAN-адрес backend:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.10:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=my-phone
```

## Development source

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=demo-device-1 \
  --dart-define=ENABLE_DEMO_ACTIVITY_SYNC=true \
  --dart-define=DEMO_STEP_TOTAL=6842 \
  --dart-define=ACTIVITY_TIME_ZONE=Europe/Berlin
```

При включённом флаге UI явно пишет **«Синхронизировать тестовые шаги»**. Без флага platform source используется по умолчанию на Android/iOS.

## Ошибки, различимые в текущем spike

- неподдерживаемая платформа;
- Health Connect отсутствует;
- Health Connect требует установки/обновления;
- Android activity recognition denied/restricted/permanently denied;
- read authorization не предоставлена;
- защищённые HealthKit-данные недоступны на заблокированном устройстве;
- IANA timezone не получена;
- чтение системного хранилища завершилось ошибкой;
- backend/network error.

Ошибка отображается через SnackBar; существующий home state остаётся доступным.

## Данные и приватность

Mobile не отправляет сырые health records. В backend уходят:

```text
технический user/device id
локальная дата
IANA timezone
cumulative step total
idempotency key
```

Не отправляются:

```text
пульс
сон
вес
геолокация
медицинские записи
полный список источников HealthKit/Health Connect
```

`includeManualEntries=false` используется как best-effort снижение риска, а не как достаточная антифрод-гарантия.

## Проверки

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

Последняя команда требует macOS/Xcode.

Unit/widget tests покрывают:

- локальную полночь и IANA timezone;
- null total → 0;
- Health Connect unavailable/update required;
- Android permission flow;
- permanent denial;
- Health authorization denial;
- locked HealthKit protected data;
- retry idempotency;
- `sync → reload authoritative home`.

## Что ещё необходимо проверить на устройствах

- iPhone без Apple Watch и с Apple Watch;
- Android с несколькими источниками Health Connect;
- ручной ввод и удаление шагов;
- смену часового пояса и переход через полночь;
- отзыв разрешения после успешной синхронизации;
- повтор после переустановки приложения;
- реальное потребление батареи;
- тексты privacy rationale перед публикацией.
