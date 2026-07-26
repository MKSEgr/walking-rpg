# Walking RPG

Монорепозиторий мобильной walking-RPG для iOS и Android.

Главный документ проекта: **[PROJECT_VISION.md](PROJECT_VISION.md)**.

## Текущее состояние

Первый технический игровой цикл уже работает сквозным образом:

```text
суммарные шаги текущего дня
→ идемпотентная синхронизация активности
→ ENERGY wallet + append-only ledger
→ продвижение экспедиции
→ выбор в первом событии
→ постоянные XP пилота и bond питомца
→ завершённое состояние экспедиции
```

В проекте реализованы:

- Java 21 / Spring Boot backend;
- Flutter mobile;
- PostgreSQL + Flyway;
- Apple HealthKit и Google Health Connect как foreground-источники шагов;
- development-only источник шагов для воспроизводимых локальных проверок;
- server-authoritative ENERGY economy;
- production `GET /api/v1/home`;
- стартовая экспедиция, первый узел и событие с двумя решениями;
- постоянный progression пилота и питомца;
- GitHub Actions для backend, Flutter, Android APK и iOS Simulator build.

## Платформенные шаги

Обычный Android/iOS запуск использует системное хранилище здоровья:

```text
Android → Health Connect
 iOS    → Apple HealthKit
```

Приложение запрашивает только чтение количества шагов. Оно не запрашивает пульс, сон, вес, геолокацию или медицинские записи. Mobile формирует cumulative total за текущий локальный день и отправляет на backend:

```text
localDate + IANA timeZone + authoritativeTotal
```

Клиент не рассчитывает энергию и не изменяет баланс оптимистично. После успешного `POST /api/v1/activity/sync` приложение заново читает `GET /api/v1/home`.

Текущая интеграция работает только по явному действию пользователя в foreground. Код, unit/widget tests, Android debug APK и iOS Simulator build проверены CI. Проверка чтения реальных данных на физических телефонах и часах остаётся отдельным этапом. Подробности: [docs/HEALTH_API_SPIKE.md](docs/HEALTH_API_SPIKE.md).

## Структура

```text
.
├── PROJECT_VISION.md
├── CONTRIBUTING.md
├── backend/
├── mobile/
│   ├── android/
│   └── ios/
├── docs/
├── scripts/
└── compose.yaml
```

Android- и iOS-host проекты находятся в репозитории и не генерируются при каждом клонировании.

## Быстрый запуск backend

Требования:

- JDK 21;
- Docker;
- доступ в интернет при первой загрузке Maven Wrapper и зависимостей.

```bash
docker compose up -d postgres
cd backend
./mvnw spring-boot:run
```

Windows:

```powershell
docker compose up -d postgres
cd backend
.\mvnw.cmd spring-boot:run
```

Основные endpoint-ы:

```text
GET  /actuator/health
GET  /api/v1/system/info
GET  /api/v1/home?localDate=YYYY-MM-DD
POST /api/v1/activity/sync
POST /api/v1/expeditions/starter-expedition-v1/advance
POST /api/v1/events/signal-source-v1/resolve
```

Подробности: [backend/README.md](backend/README.md).

## Быстрый запуск mobile

Требования:

- Flutter 3.44.7;
- Android SDK и/или Xcode;
- запущенный backend.

Android Emulator:

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=android-emulator-1
```

iOS Simulator:

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=ios-simulator-1
```

На физическом устройстве вместо loopback/emulator host указывается LAN-адрес компьютера с backend.

В Android/iOS приложении появляется действие **«Синхронизировать шаги»**. Разрешения запрашиваются в момент этого действия.

### Явный development-режим

Для проверки без HealthKit/Health Connect:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=demo-device-1 \
  --dart-define=ENABLE_DEMO_ACTIVITY_SYNC=true \
  --dart-define=DEMO_STEP_TOTAL=6842 \
  --dart-define=ACTIVITY_TIME_ZONE=Europe/Berlin
```

Этот источник никогда не включается без явного feature flag.

Подробности: [mobile/README.md](mobile/README.md).

## Проверки

Pull request CI выполняет:

```text
Project structure
Backend compile + unit/API tests
Flyway V1–V4 + PostgreSQL Testcontainers tests
Dart formatting + Flutter analyze + Flutter tests
Android debug APK build
iOS Simulator debug build
```

Локально:

```bash
./scripts/verify-project.sh
./scripts/bootstrap-mobile.sh
```

## Текущие границы

Пока не реализованы:

- проверка на физических iPhone/Android и связках телефон + часы;
- background delivery;
- offline command queue;
- attestation;
- полноценный anti-fraud по источникам;
- store privacy forms и production privacy-policy flow;
- второй узел экспедиции, предметы, навыки и эволюция.

Дальнейший порядок работ: [docs/ROADMAP.md](docs/ROADMAP.md).
