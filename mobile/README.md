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

## Язык регистрации и первого пути

Step Beyond поддерживает явный выбор русского или английского языка до входа.
Русский показывается первым; системная locale, identity, health- и location-данные
не используются для автоматического выбора.

Настройка хранится в secure storage под ключом `step_beyond_locale_v1` как
device-scoped preference. Она находится вне OIDC session envelope и owner-local
cache/outbox, поэтому переживает restart, logout и смену аккаунта. Изменить язык
обратно можно на экране входа, в «Первом пути» и через действие языка на экране
аккаунта.

Миграция для сборок без сохранённого значения fail-safe: используется русский
fallback и показывается обязательный экран подтверждения. Неизвестное или
повреждённое значение проходит тот же путь. Статическая копия auth/first-journey
и presentation-mapping канонического стартового контента находятся в
`lib/l10n/app_en.arb` и `lib/l10n/app_ru.arb`; неизвестный server-owned content
показывается буквально и не влияет на IDs, команды или server-authoritative
state.

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
POST /api/v1/event-results/{receiptId}/acknowledge
POST /api/v1/crafting/recipes/{recipeId}/craft
POST /api/v1/item-upgrades/{upgradeId}/apply
POST /api/v1/equipment/slots/{slotId}/equip
POST /api/v1/equipment/slots/{slotId}/unequip
POST /api/v1/platform/commands
```

Versioned JSON store находится в application-support directory. Запись использует target, `.tmp` и `.bak`; при прерывании замены выбирается последняя валидная копия. Повреждённый store не перезаписывается молча.

Команды разделены на три lane:

```text
ACTIVITY — синхронизация шагов
GAMEPLAY — продвижение экспедиции, решение/подтверждение события, crafting,
           item upgrade, equipment и изменяющие state platform-команды
TELEMETRY — RECORD_EXPERIMENT_EXPOSURE
```

Внутри lane действует FIFO. При replay `ACTIVITY` завершается до `GAMEPLAY`,
потому что activity sync может зачислить ENERGY для следующего advance.
Retryable ACTIVITY останавливает state-changing цепочку: GAMEPLAY не
отправляется и остаётся `PENDING` до следующего replay.
`TELEMETRY` выполняется параллельно со всей state-changing цепочкой, поэтому
недоступная exposure не блокирует gameplay или первый экран. Startup replay
возвращает результат после ACTIVITY/GAMEPLAY, а close-tracked TELEMETRY
завершается отдельно и обновляет recovery badge. Явный retry в Recovery ждёт
итог всех lane. Network/transport error, `408`,
`429`, `5xx` и неоднозначный response остаются pending. Подтверждённые
остальные `4xx` переходят в failed и не блокируют очередь.

Для event-result acknowledgement outbox хранит `receiptId` и replay-ит тот же
bodyless URL после restart. Локальный command key нужен файловой очереди, но не
передаётся backend: единственный server-side idempotency scope — сам receipt.

На старте authenticated shell pending-команды текущего owner replay-ятся один
раз в foreground. Runtime memoize-ит первую startup Future до конца
authenticated session, поэтому rebuild, resume и reload не отправляют
`PENDING` повторно. Первый всё ещё активный UI-владелец claim-ит завершённый
startup report/error один раз: in-flight remount принимает outcome, а remount
после обработки не повторяет старый Snackbar или generation refresh. После
завершения startup attempt UI resume/reload читает только authoritative
Home/Platform. Close, logout или замена runtime прекращает stale continuation
без новых owner-scoped reads.
`ActivitySyncShell` имеет default `replayOnStart = false`, а явный opt-in
требует injected session-owned runtime; созданный shell runtime закрывается
при dispose и startup replay не запускает. Новый однократный replay появляется
с новым runtime после process restart или 401 reauthentication. Повторного
автоматического startup retry в текущей runtime нет; ручная попытка из
Recovery вызывает `replayPending`. Обычный новый business submit сохраняет
FIFO и может сначала обработать более старый `PENDING` своей lane. После
успешного ACTIVITY/GAMEPLAY startup replay приложение перечитывает authoritative
home; telemetry-only completion обновляет recovery badge. Автоматического
background worker-а пока нет.

Экран **«Сохранённые действия»** доступен из первого пути, home, путевого
журнала и аккаунта. Он не показывает payload, idempotency key, fingerprint,
receipt, Health cursor, raw error или путь к store.

- `PENDING` можно повторить только существующим replay исходной записи; удалять
  такую запись нельзя.
- `FAILED` больше не отправляется. Его можно убрать только как локальную
  диагностическую запись после подтверждения; server state не меняется.
- ошибка чтения store остаётся видимой и не приводит к автоматическому reset.
- успешный ручной replay заставляет shell перечитать authoritative state.
- targeted refresh/resume читает authoritative state, не повторяет startup
  replay и не перемонтирует уже открытый основной shell; при потере
  authenticated-сессии owner-scoped routes закрываются.

Optional `lastFailureCategory` и динамическая telemetry lane совместимы со
старыми v1-файлами без миграции envelope.

## Read-only offline cache

Последние успешно декодированные server snapshots сохраняются отдельно от command outbox:

```text
home     — owner + localDate, TTL 36 часов
platform — owner + current, TTL 7 дней
```

Cache используется только при transport error, `408`, `429`, `5xx` или некорректном успешном snapshot backend. `401`, `403`, validation/state conflicts и остальные terminal `4xx` никогда не маскируются cached state.

В cached-режиме UI показывает время сохранения и причину fallback, разрешает refresh, но блокирует expedition/event/platform mutations. Cached home не используется как подтверждение доступного ENERGY. Перед state-changing запросом зависимые snapshots инвалидируются: при неоднозначном transport failure старое состояние не должно снова появиться как безопасный fallback.

Файловое хранилище versioned, ограничено по размеру и количеству записей, изолировано по owner и использует atomic target/temporary/backup recovery. Повреждённый snapshot удаляется или помещается в quarantine и не показывается пользователю.

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

Изменения отправляются одной командной ручкой
`POST /api/v1/platform/commands`. Mobile не вычисляет progression и не
применяет optimistic rewards: успешный response уже содержит authoritative
`snapshot`, которым заменяется экран. Изменяющие state platform-команды
проходят через restart-safe GAMEPLAY lane, поэтому payload и idempotency key
сохраняются до подтверждённого ответа backend.

Sandbox-покупка показывается только для свежего authoritative snapshot, когда
effective remote config возвращает `sandboxPaymentsEnabled=true`, и только в
non-release Flutter build. Cached snapshot, отключённый backend provider или
release build скрывают кнопку, sandbox-цену и sandbox-текст; устаревший callback
также не отправляет команду. Опоздавшая загрузка не может вернуть capability
после принятого command snapshot. Уже полученная косметика и остальные
неплатёжные действия журнала продолжают работать по обычным правилам.

Назначенные A/B-варианты регистрируются отдельной идемпотентной командой `RECORD_EXPERIMENT_EXPOSURE`. Ключ включает content version, experiment id и variant, поэтому повторный запуск приложения не создаёт дублирующий exposure event.
Exposure сохраняется тем же outbox, но выполняется в отдельной `TELEMETRY`
lane и не задерживает игровой handoff.

Навигация сохраняет состояние главного экрана и журнала через `IndexedStack`. Кнопка синхронизации шагов показывается только на вкладке экспедиции.

## Первый путь

После входа `FirstJourneyGate` ведёт нового пользователя по одному
authoritative flow:

```text
знакомство
→ STEPS permission и sync
→ reward ENERGY
→ выбор Искры / Мха / Руны
→ расход ENERGY на outer-beacon
→ решение signal-source-v1
→ подтверждение durable result receipt, если handoffRequired=true
→ основная экспедиция
```

Экран можно закрыть через «Продолжить позже» и снова открыть из «Путевого
журнала». Все mutations проходят существующий durable outbox. После restart
шаги, sync, достигнутый узел и resolved event восстанавливаются из server
facts. Если response события был потерян или приложение завершилось до показа
награды, `pendingEventResult` возвращает ту же карточку, а завершение первого
пути отправляет ACK через GAMEPLAY lane. Отсутствующие milestones записываются
идемпотентно. Cached snapshot остаётся read-only.

Mobile объявляет `X-Walking-RPG-Capabilities: durable-event-result-v1` при
resolution и доверяет response `handoffRequired`, а не факту отправки header.
Пока backend cluster gate выключен, response остаётся legacy delivery даже с
этим header. Response старого backend без `receiptId`, `handoffRequired` и
`nextNode` также не требует ACK. Gate включается операционно только после
полного drain старых backend instances. Если capable-устройство уже создало
pending receipt, старый клиент того же аккаунта нужно обновить либо завершить
handoff на capable-устройстве.

`SELECT_PET` — реальный игровой выбор: выбранный питомец возвращается в home и
получает bond за события. Вибрация и анимация являются только feedback и не
блокируют server reload.

## Первая глава, persistent inventory и equipment

Главный экран читает `chapter-1-v2` через `GET /api/v1/home` и не хранит
локальную копию игрового прогресса. Глава содержит 18 основных узлов и
опциональный `resonance-pocket`. После первого
события authoritative reload показывает второй узел `lumen-gate`; после его
события маршрут продолжается на `ash-orbit`.

Варианты второго события содержат preview материальной награды. После
resolution authoritative `GET /home` возвращает top-level
`pendingEventResult`: receipt, выбор, XP/bond/material snapshot и nullable
следующий узел. UI показывает отдельную result card до явного подтверждения, а
карточка **«Инвентарь»** отображает текущие item и quantity. Результат
восстанавливается после restart; cached snapshot также показывает его, но не
разрешает ACK. Поддерживаются:

```text
2 × Люминовый осколок
1 × Нить эха
```

Event resolution использует generic durable outbox, поэтому `eventId`,
`choiceId` и исходный key сохраняются и replay-ятся. Для
`handoffRequired = true` подтверждение result card использует отдельный
`EVENT_RESULT_ACKNOWLEDGEMENT` в той же GAMEPLAY lane: persist-before-send
хранит `receiptId`, HTTP POST не имеет body, успешный replay возвращает
стабильное время первого ACK. Пока capable receipt pending, backend и UI не
разрешают следующий advance/resolution той же экспедиции. Optimistic update XP,
bond, inventory или статуса экспедиции не выполняется: после resolution и ACK
всегда перечитывается home.

Home дополнительно возвращает versioned `craftingRecipes`. До активации
`chapter-1-v5` это `resonance-compass-v1`; после активации добавляется
`prism-sextant-v1` из поздних материалов главы. Карточка
**«Мастерская»** показывает authoritative стоимость и статус:

```text
2 × Люминовый осколок + 1 × Нить эха
→ Резонансный компас · уникальный предмет
```

Кнопка доступна только для свежего `READY` snapshot без pending event result.
`CRAFTING` сохраняет только `recipeId` и исходный idempotency key в GAMEPLAY
outbox. Успешный response не применяется оптимистично: mobile инвалидирует
read cache и перечитывает home, где materials уже списаны, unique item добавлен,
а recipe имеет статус `CRAFTED`. Cached snapshot показывает recipe read-only.

При active `chapter-1-v5` Home также возвращает `itemUpgrades`. Карточка
**«Калибровка снаряжения»** показывает состояния
`LOCKED|MISSING_MATERIALS|READY|COMPLETED`, стоимость и переход
`1/UNCOMMON → 2/RARE`. `ITEM_UPGRADE` сохраняет только server-owned
`upgradeId` и исходный key в GAMEPLAY outbox. Успешный response не меняет
локальный inventory: cache инвалидируется, после чего Home перечитывает тот же
`itemInstanceId`, новый level/rarity и остатки материалов.

При active `chapter-1-v6` событие спектральной обсерватории получает
`trace-second-dawn`. Home держит choice заблокированным, пока в `NAVIGATION` не
экипирован `prism-sextant` с `minimumUpgradeLevel = 2`; legacy requirement без
поля трактуется как level 1. Mobile показывает server-owned lock reason, но не
рассчитывает доступность локально.

При active `chapter-1-v7` финальный `dawn-relay-v1` получает
`open-second-dawn` с тем же requirement уровня 2. Доступный choice переводит к
optional `second-dawn-threshold`; оба решения этого эпилога завершают
экспедицию после server-owned награды. Mobile использует exact-ID visual marks
для финального choice, нового узла и обоих решений, не выводя identity из
переведённого текста.

Карточка **«Снаряжение»** показывает authoritative slot `NAVIGATION` и
позволяет экипировать/снять созданный `resonance-compass` или
`prism-sextant`; второй прибор атомарно заменяет первый. `EQUIPMENT`
сохраняет `slotId`, action, nullable `itemInstanceId` и исходный key до первой
отправки. После успеха client инвалидирует read cache и перечитывает home;
локального optimistic loadout нет.

В событии `mirror-delta-v1` home помечает `follow-resonance` как доступный
только при экипированном компасе и возвращает пользовательскую причину lock.
Недоступный choice нельзя отправить из UI, но backend всё равно повторно
проверяет prerequisite. Доступный choice ведёт через `resonance-pocket` и
возвращает экспедицию в `storm-archive`; основной маршрут не меняется.
Для rolling compatibility backend оставляет в legacy `choices` только
доступные варианты, а locked варианты возвращает в additive `lockedChoices`:
новый mobile объединяет их для UI, старый остаётся на основном маршруте.

Свежий network Home дополнительно регистрирует состояния compass journey:
recipe `MISSING_MATERIALS`/`READY`/`CRAFTED` и gated choice
`LOCKED`/`AVAILABLE`. Impression создаётся только после входа соответствующей
card во viewport, когда Home выбрана, её route текущая и приложение `resumed`.
Accepted snapshot ждёт возврата из Journal, Account/Recovery или background;
cached snapshot ничего не отправляет. Для каждого content/state используется
детерминированный idempotency key, поэтому reload или restart не создаёт вторую
server event; при недоставленной попытке durable outbox сохраняет исходный
payload/key. Если Home-запрос был заменён новым до завершения, его snapshot не
считается показанным и impression не отправляется.

`RECORD_COMPASS_IMPRESSION` классифицируется как `TELEMETRY`: он не
инвалидирует Home/Platform cache, не применяет optimistic state и не удерживает
ACTIVITY/GAMEPLAY recovery. Эти показы остаются client-reported; craft/equip/
route facts для beta analytics backend получает только из persistent gameplay
receipts.

## Минимальные платформенные настройки

### Android

- project `compileSdk = 36` and `targetSdk = 36`;
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
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=android-emulator-1
```

iOS Simulator:

```bash
flutter pub get
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=ios-simulator-1
```

Для чтения настоящих данных нужен физический телефон с настроенным HealthKit/Health Connect. Simulator CI подтверждает компиляцию и linking, но не заменяет device-проверку.

На физическом устройстве задаётся LAN-адрес backend:

```bash
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://192.168.1.10:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=my-phone
```

## Development source

```bash
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=DEMO_USER_ID=demo-user-1 \
  --dart-define=DEMO_DEVICE_ID=demo-device-1 \
  --dart-define=ENABLE_DEMO_ACTIVITY_SYNC=true \
  --dart-define=DEMO_STEP_TOTAL=6842 \
  --dart-define=ACTIVITY_TIME_ZONE=Europe/Berlin
```

При включённом флаге UI явно пишет **«Синхронизировать тестовые шаги»**. Без флага platform source используется по умолчанию на Android/iOS.

## Internal Validation Center

`ValidationCenterScreen` предназначен только для сбора evidence во время
ручного physical-device прогона. Он по умолчанию отсутствует и включается
явным compile-time flag только в non-release build:

```bash
SOURCE_GIT_SHA=$(git rev-parse HEAD)
flutter run \
  --dart-define=MOBILE_AUTH_MODE=development \
  --dart-define=API_BASE_URL=http://192.168.1.10:8080 \
  --dart-define=DEMO_USER_ID=validation-owner \
  --dart-define=DEMO_DEVICE_ID=validation-device \
  --dart-define=ENABLE_VALIDATION_CENTER=true \
  --dart-define=VALIDATION_SOURCE_GIT_SHA="$SOURCE_GIT_SHA"
```

App version и build number читаются из фактически установленного native package
через `PackageInfo`, а source SHA передаётся из clean checkout. При
`kReleaseMode`, невалидном SHA или недоступной app/build metadata конфигурация
отклоняется fail-closed. Флаг нельзя
использовать для production diagnostics или включать в store candidate.

Центр хранит не более 64 ordered checkpoints только в памяти одного
authenticated owner и одной ревизии auth-сессии. Он фиксирует
platform/OS/app/build и coarse permission, provider, aggregated read, sync и
authoritative reload outcomes. Live owner/session повторно проверяются после
async boundaries. Logout, новая сессия, account switch, controller disposal или
process termination удаляет journal; owner/revision нужны для runtime-изоляции,
но не экспортируются.
Permission state `request_succeeded` означает успешное завершение platform
request, а не гарантированный read grant: HealthKit не всегда раскрывает
приложению фактический статус разрешения.

Явный export создаёт redacted
`walking-rpg-device-validation-evidence-v1` JSON размером не более 64 KiB с
policy `walking-rpg-evidence-redaction-v1`, exact source SHA и SHA-256 checksum.
Temporary-файл передаётся platform share sheet и удаляется в `finally` после
возврата или ошибки share. Уже переданная копия остаётся в выбранном
тестировщиком хранилище.

Journal/export не содержит raw health samples, tokens, account/device/command
identifiers, idempotency keys, provider record IDs, endpoints, request/response
bodies, filesystem paths или raw errors. Unknown/free-form facts не копируются
в schema-v1. Полный workflow, checksum review и ручной шаблон описаны в
[`DEVICE_VALIDATION_PROTOCOL.md`](../docs/DEVICE_VALIDATION_PROTOCOL.md).

Готовый экран и зелёные tests не закрывают physical gate: iPhone/Android,
provider/watch, permission revoke, timezone/midnight и battery scenarios
остаются `EXTERNAL_VALIDATION_REQUIRED` до датированного review evidence.

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

Health/network ошибки отображаются через SnackBar; существующий home state
остаётся доступным. Состояние command store дополнительно остаётся видимым на
экране **«Сохранённые действия»** без raw diagnostics.

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
- persist-before-send и exact key replay для
  activity/expedition/event/platform;
- persist-before-send/restart replay receipt для bodyless event-result ACK;
- persist-before-send/restart replay crafting recipe с исходным key;
- persist-before-send/restart replay item upgrade с исходным key;
- persist-before-send/restart replay equip/unequip с исходным payload/key;
- FIFO внутри lanes, порядок ACTIVITY → GAMEPLAY и параллельная TELEMETRY;
- temporary/backup/corruption recovery файлового store;
- единственный startup replay → reload authoritative home;
- owner-scoped recovery projection без payload/key/raw error;
- manual replay `PENDING`, запрет его удаления и dismiss только `FAILED`;
- fail-closed recovery UI при corruption;
- legacy v1 exposure → TELEMETRY без schema migration;
- fail-closed Validation Center policy, exact source/build metadata, bounded
  per-launch journal, schema-v1 redaction/checksum и temporary share cleanup;
- `sync → reload authoritative home`;
- переход первого события на второй узел;
- resolution второго события, material preview/result и inventory rendering;
- parsing/UI/API error mapping crafting recipe/item upgrade, unique item,
  level/rarity и authoritative reload; read-only cached mutations;
- полный widget flow locked choice → equip → unlocked choice → unequip →
  locked choice без optimistic state;
- compass widget telemetry только после viewport exposure при selected/current/
  resumed Home; superseded, hidden, covered и background snapshots отложены;
- parsing и restart-visible rendering top-level `pendingEventResult`;
- ACK result card, authoritative reload и read-only cached card;
- restart-safe replay второго события с исходным payload/key;
- parsing/validation `dailyGoalPolicy` и отображение default/adaptive explanation;
- mapping platform snapshot и platform command response;
- onboarding/pet/skill/quest/season/squad/cosmetic widget flows;
- fail-closed sandbox purchase UI для cached/disabled/release состояний без
  блокировки уже полученной косметики;
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

## Production authentication

Production mobile builds use `MOBILE_AUTH_MODE=oidc` and the Authorization Code
flow with PKCE. Required build-time values:

```bash
--dart-define=MOBILE_AUTH_MODE=oidc
--dart-define=API_BASE_URL=https://api.example.com
--dart-define=OIDC_ISSUER=https://tenant-name.eu.auth0.com/
--dart-define=OIDC_AUDIENCE=https://api.stepbeyond.game
--dart-define=OIDC_CLIENT_ID=walking-rpg-mobile
--dart-define=OIDC_SCOPES="openid profile offline_access walking-rpg.user"
```

The registered redirect URIs are:

```text
com.walkingrpg.app:/oauthredirect
com.walkingrpg.app:/logout
```

The `walking-rpg.user` scope is required by the backend's default JWT
authority mapping for every `/api/v1/**` endpoint.

The selected Russian or English locale is passed to Universal Login. A random
installation ID is kept in platform secure storage, survives logout and account
switch, and is sent only to Auth0 so its Action can issue the signed namespaced
device claim. See [ADR 0035](../docs/adr/0035-auth0-alpha-authentication-contract.md).

Release-quality builds read optional repository variables
`MOBILE_RELEASE_API_BASE_URL`, `MOBILE_RELEASE_OIDC_ISSUER`,
`MOBILE_RELEASE_OIDC_AUDIENCE`, and `MOBILE_RELEASE_OIDC_CLIENT_ID`. When they
are absent, CI embeds reserved
`.invalid` endpoints so unsigned technical artifacts remain configuration-valid
without contacting a real identity system; production signing must provide the
deployment values.

Ordinary release-quality builds remain unsigned. Protected Android signing is
an explicit opt-in through an external `walkingRpgSigningProperties` Gradle
property; repository-local key files and debug-key fallback are rejected.
Android/iOS signing prerequisites, invocation and evidence rules are documented
in [PROTECTED_MOBILE_SIGNING.md](../docs/PROTECTED_MOBILE_SIGNING.md).

Access, refresh and ID tokens are stored in Keychain/Android secure storage.
A secure owner tombstone preserves account-switch cleanup across process restarts, and
iOS disables URL disk caching before AppAuth starts. Only the Bearer transport may
attach `Authorization`, and it refuses to send a
token outside the configured API origin. A single 401 triggers one serialized
refresh and one replay of the identical request. Only OAuth `server_error`,
`temporarily_unavailable`, and non-protocol platform failures are retried;
permanent OAuth errors require reauthentication. A second 401 requires an
interactive sign-in and leaves durable pending commands available for the same
account.

Local header authentication remains available only in non-release builds:

```bash
--dart-define=MOBILE_AUTH_MODE=development
--dart-define=API_BASE_URL=http://10.0.2.2:8080
--dart-define=DEMO_USER_ID=demo-user-1
--dart-define=DEMO_DEVICE_ID=android-emulator-1
```

Explicit logout waits for admitted command work to finish, then clears the
current account's read cache, durable command outbox and secure token set.
