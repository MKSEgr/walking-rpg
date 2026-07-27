# Walking RPG Mobile

Flutter-клиент walking-RPG. Android- и iOS-host проекты зафиксированы в репозитории.

## Стек

- Flutter 3.44.7;
- Dart 3.8+;
- `health` 13.3.1;
- `permission_handler` 12.0.3;
- `flutter_timezone` 5.1.0;
- `path_provider` 2.1.6 для application-support command store;
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
6. `ActivitySyncCoordinator` передаёт чтение в durable command outbox.
7. Outbox сохраняет payload и idempotency key до первой сетевой попытки.
8. Команда отправляется в `POST /api/v1/activity/sync`.
9. После успеха приложение полностью перечитывает `GET /api/v1/home`.

При повторе того же чтения после сетевой ошибки или process restart используется сохранённый idempotency key. Изменившееся чтение создаёт новую команду и выполняется после более ранней activity-команды.


## Персональная дневная цель

Mobile не вычисляет цель локально. `GET /api/v1/home` возвращает `dailyGoal` и `dailyGoalPolicy`. Карточка активности показывает:

- при cold start — сколько активных дней ещё собрано до перехода к адаптивной цели;
- при adaptive policy — baseline-медиану, количество активных дней и процент роста;
- при rolling deploy со старым backend — нейтральную подпись без попытки восстановить формулу на клиенте.

Текущая политика backend: медиана положительных accepted total за предыдущие 7 локальных дней, `+5%`, округление до 250, диапазон 2 000–12 000; при истории менее 3 дней — цель 6 000.

## Durable command outbox

Одинаковый persist-before-send поток используется для:

```text
POST /api/v1/activity/sync
POST /api/v1/expeditions/{expeditionId}/advance
POST /api/v1/events/{eventId}/resolve
POST /api/v1/platform/commands
```

Versioned JSON store находится в application-support directory. Запись использует target, `.tmp` и `.bak`; при прерывании замены выбирается последняя валидная копия. Повреждённый store не перезаписывается молча.

Команды разделены на две lane:

```text
ACTIVITY — синхронизация шагов
GAMEPLAY — продвижение экспедиции, решение события и platform-команды
```

Внутри lane действует FIFO. Временная ошибка GAMEPLAY не блокирует ACTIVITY и наоборот. Network/transport error, `408`, `429`, `5xx` и неоднозначный response остаются pending. Подтверждённые остальные `4xx` переходят в failed и не блокируют очередь.

На старте приложения pending-команды текущего технического пользователя replay-ятся один раз в foreground. После успешного replay приложение перечитывает authoritative home. Автоматического background worker-а и offline read cache пока нет.

## Путевой журнал и platform state

Вторая вкладка приложения читает `GET /api/v1/platform` и отображает server-owned состояние roadmap-функций:

```text
onboarding
три питомца и эволюция
навыки пилота
задания и достижения
сезон и недельный маршрут
отряд
косметика и sandbox-покупки
A/B assignments и remote config diagnostics
```

Изменения отправляются одной командной ручкой `POST /api/v1/platform/commands`. Mobile не вычисляет progression и не применяет optimistic rewards: успешный response уже содержит authoritative `snapshot`, которым заменяется экран. Platform-команды проходят через ту же restart-safe GAMEPLAY lane, поэтому payload и idempotency key сохраняются до подтверждённого ответа backend.

Назначенные A/B-варианты регистрируются отдельной идемпотентной командой `RECORD_EXPERIMENT_EXPOSURE`. Ключ включает content version, experiment id и variant, поэтому повторный запуск приложения не создаёт дублирующий exposure event.

Навигация сохраняет состояние главного экрана и журнала через `IndexedStack`. Кнопка синхронизации шагов показывается только на вкладке экспедиции.

## Два узла и persistent inventory

Главный экран читает `starter-v2` через `GET /api/v1/home` и не хранит локальную копию игрового прогресса. После первого события authoritative reload показывает второй узел `lumen-gate`. После накопления и расхода ещё 45 ENERGY открывается `echo-vault-v1`.

Варианты второго события содержат preview материальной награды. После успешного resolution UI показывает исход события и новый stack, а отдельная карточка **«Инвентарь»** отображает текущие item и quantity. Поддерживаются:

```text
2 × Люминовый осколок
1 × Нить эха
```

Event-команда уже использует generic durable outbox, поэтому второй `eventId` и его `choiceId` сохраняются и replay-ятся без нового типа команды. Optimistic update XP, bond, inventory или статуса экспедиции не выполняется: после ответа всегда перечитывается home.

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
- backend/network error;
- повреждённое локальное command store.

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
- retry idempotency в рамках процесса и после restart;
- persist-before-send и exact key replay для activity/expedition/event/platform;
- FIFO и независимость ACTIVITY/GAMEPLAY lanes;
- temporary/backup/corruption recovery файлового store;
- startup replay → reload authoritative home;
- `sync → reload authoritative home`;
- переход первого события на второй узел;
- resolution второго события, material preview/result и inventory rendering;
- restart-safe replay второго события с исходным payload/key;
- parsing/validation `dailyGoalPolicy` и отображение default/adaptive explanation;
- mapping platform snapshot и platform command response;
- onboarding/pet/skill/quest/season/squad/cosmetic widget flows;
- restart-safe replay platform-команд и канонизацию payload независимо от порядка ключей;
- навигацию между экспедицией и путевым журналом.

## Что ещё необходимо проверить на устройствах

- iPhone без Apple Watch и с Apple Watch;
- Android с несколькими источниками Health Connect;
- ручной ввод и удаление шагов;
- смену часового пояса и переход через полночь;
- отзыв разрешения после успешной синхронизации;
- повтор после переустановки приложения;
- реальное потребление батареи;
- тексты privacy rationale перед публикацией.
