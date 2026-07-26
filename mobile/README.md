# Walking RPG Mobile

Flutter-приложение walking-RPG.

## Host-проекты

Каталоги `android/` и `ios/` пока генерируются установленной локально версией Flutter:

```bash
flutter create --platforms=android,ios \
  --org com.walkingrpg \
  --project-name walking_rpg_mobile .
flutter pub get
```

При подключении HealthKit/Health Connect host-проекты будут зафиксированы в репозитории вместе с permissions и platform bridge.

## Production-поток

Главный экран:

- загружает `GET /api/v1/home`;
- показывает server-authoritative шаги, ENERGY, экспедицию, событие и progression;
- отправляет команды advance и event resolution;
- после каждой успешной команды перечитывает home;
- не выполняет optimistic изменение server state.

## Activity boundary

Mobile разделяет две ответственности:

```text
StepSource
  читает authoritative total из platform/development source

ActivityApiClient
  отправляет reading в POST /api/v1/activity/sync
```

`ActivitySyncCoordinator` сохраняет один idempotency key при повторе того же reading после ошибки. Если reading изменился, создаётся новый key.

## Development source

Тестовый источник выключен по умолчанию. Для явного включения:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=demo-device-1 \
  --dart-define=ENABLE_DEMO_ACTIVITY_SYNC=true \
  --dart-define=DEMO_STEP_TOTAL=6842 \
  --dart-define=ACTIVITY_TIME_ZONE=Europe/Berlin
```

Параметры:

```text
API_BASE_URL                 backend URL
DEMO_USER_ID                 временный X-User-Id
DEMO_DEVICE_ID               временный X-Device-Id
ENABLE_DEMO_ACTIVITY_SYNC    показывает development-команду
DEMO_STEP_TOTAL              cumulative authoritative total
ACTIVITY_TIME_ZONE           IANA Zone ID, например Europe/Berlin
```

Без `ENABLE_DEMO_ACTIVITY_SYNC=true` тестовая кнопка не отображается и фиктивные шаги не отправляются.

## Тесты

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

Покрыты JSON mapping, HTTP-клиенты, idempotency retry coordinator и widget-flow `sync → reload home`.

## Следующий шаг

Реализовать platform `StepSource` для Apple Health и Health Connect, не меняя `ActivityApiClient` и экранную команду.
