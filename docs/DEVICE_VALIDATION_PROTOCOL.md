# Device validation protocol

## Цель и граница статуса

Подтвердить на физических устройствах, что приложение получает корректный
aggregated daily total, не удваивает награды и устойчиво восстанавливается при
изменениях health data и lifecycle ОС.

Внутренний **Validation Center** собирает обезличенный технический журнал и
schema-v1 JSON. Готовность этого инструмента является `CODE_COMPLETE`, но не
означает, что хотя бы один физический сценарий пройден. Пока заполненный
шаблон, JSON и датированное заключение не проверены, соответствующие пункты
остаются `EXTERNAL_VALIDATION_REQUIRED`.

Эмулятор, iOS Simulator, development source и synthetic fixture разрешены для
проверки кода центра, но не принимаются как evidence реального HealthKit или
Health Connect.

## Включение внутреннего центра

Центр по умолчанию выключен. Для внутреннего non-release запуска нужны все
определения:

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

Версия приложения и build number читаются из установленного native package
через `PackageInfo`; независимые dart-defines для этих значений не принимаются.
Незакоммиченные изменения делают source-привязку недостоверной и не
допускаются в принимаемом evidence.

`ENABLE_VALIDATION_CENTER=true` в release build отклоняется fail-closed.
Невалидный SHA, недоступные app version/build number или попытка обойти проверку
также не должны приводить к доступному центру. Это внутренний инструмент, а не
production diagnostics.

## Жизненный цикл журнала

- журнал создаётся в памяти для одного authenticated owner и одной ревизии
  auth-сессии в рамках запуска;
- owner используется только для runtime-изоляции и не попадает в export;
- live owner и ревизия auth-сессии повторно проверяются после каждого async
  checkpoint; logout, новая сессия, смена owner, dispose controller или
  завершение процесса уничтожают журнал;
- журнал не записывается в preferences, cache, command outbox, application
  support directory или backend;
- максимум — 64 упорядоченные записи на запуск; normal actions используют не
  более первых 63 slots, чтобы последняя попытка переполнения могла оставить
  terminal marker;
- весь schema-v1 JSON в UTF-8 — не более 64 KiB;
- если полное действие уже не помещается, оставшийся slot получает blocked
  journal entry с `journal_limit_reached`, дальнейшие действия блокируются;
  переполнение не скрывается усечением evidence;
- `durationMs` измеряется monotonic clock и не зависит от смены timezone,
  полуночи, NTP или ручной коррекции системных часов.

Поэтому JSON необходимо экспортировать до logout, смены аккаунта или
завершения приложения.

## Inventory preflight для #149

До физического прогона используется нормативный template
`docs/evidence/health-device-inventory-template.json` со schema
`walking-rpg-health-device-inventory-v1`. Committed `recordStatus=TEMPLATE`
подтверждает только готовность contract и намеренно не является inventory
evidence.

Заполненную обезличенную копию проверяют командой:

```bash
python3 scripts/ci/verify_health_device_inventory.py \
  <approved-inventory-file.json> \
  --require-recorded
```

`--require-recorded` требует:

- exact immutable `alpha-rc2` tuple из release dossier;
- четыре обязательные строки без дублей и перестановки;
- `AVAILABLE` с model/OS, role category и явной доступностью clean install,
  upgrade, timezone/midnight и battery measurement;
- `BLOCKED` с coarse blocker category/reason вместо ложного pass;
- две различные Android data-provider categories, если обе Android-строки
  доступны; отсутствующая строка остаётся `BLOCKED`;
- только allowlisted поля без URL, email, path, UUID/device-ID/SHA-like
  значений в свободном evidence text.

`OWNER_INPUT_REQUIRED` разрешён только в template и отклоняется для
`RECORDED`. Validator не доказывает наличие устройства или выполнение
сценария: он отделяет структурно готовый inventory от внешнего owner input.
Заполненный файл версионируется только в approved evidence location после
redaction review; публичный issue/PR не используется как raw evidence storage.

## Минимальная матрица

- iPhone без Apple Watch;
- iPhone с Apple Watch;
- Android с Health Connect;
- минимум два Android data provider;
- сценарий ручной записи и коррекции.

Для каждого прогона фиксируются платформа, версия ОС, версия приложения/build,
timezone, локальная дата, permission state и exact source Git SHA. Обезличенная
provider/watch category фиксируется только в ручном evidence template рядом с
JSON: platform API не раскрывает её надёжно без запрещённых source IDs.
Серийный номер, advertising/installation/device ID, OIDC subject и другие
идентификаторы не фиксируются.

## Обязательные checkpoints

Один прогон должен сохранять причинный порядок, достаточный для разбора:

1. **Provider** — тип HealthKit/Health Connect и его доступность; обезличенная
   provider/watch category остаётся в ручном template, без provider
   record/source IDs в JSON.
2. **Permission** — запрошено ли только чтение `STEPS`, итог
   `request_succeeded`/`denied`/`settings_required`/`restricted` и результат
   повторного запроса, если он был. `request_succeeded` означает успешное
   завершение platform request, а не доказанный grant; HealthKit не всегда
   раскрывает приложению фактический read status.
3. **Read** — `succeeded`/`failed`/`blocked`, локальная дата, IANA timezone и
   только aggregated daily total; нулевой total остаётся успешным чтением, без
   отдельных samples и их timestamps.
4. **Sync** — `succeeded`/`failed`/`blocked`, coarse `errorCategory` и
   безопасные числовые значения typed result; без URL, payload, token,
   idempotency key или raw error.
5. **Authoritative checkpoint** — результат свежего server reload и
   server-owned state versions, daily/accepted totals, available ENERGY и
   journey facts; cached snapshot не выдаётся за authoritative. Один
   `contentVersion` фиксируется только после проверки равенства Home и Platform
   versions; skew нормализуется как `invalid_response`. `acceptedDelta` и
   `energyGranted` фиксируются отдельно в `latestSync`.

Если действие не достигло следующего checkpoint, это фиксируется outcome
текущего этапа и объясняется в ручном шаблоне без вставки raw exception.

## Сценарии

1. Чистая установка и разрешение только `STEPS READ`.
2. Повторная синхронизация того же total — без дополнительной награды.
3. Рост total — награда только за положительную delta.
4. Понижение total после удаления/коррекции — без отрицательной награды.
5. Ручная запись — best effort, не security boundary.
6. Отзыв и повторная выдача разрешения.
7. Переход через локальную полночь.
8. Смена IANA timezone.
9. Offline command → restart → replay с тем же внутренним idempotency key;
   само значение key не экспортируется.
10. Resume fallback после длительного background.
11. Измерение батареи на согласованном интервале.

Restart создаёт новый per-launch journal. Связь двух файлов описывается в
ручном шаблоне через нейтральные имена файлов и checksums, а не через
пользовательский или device identifier.

## Schema-v1 JSON

Export обязан иметь schema
`walking-rpg-device-validation-evidence-v1` и redaction policy
`walking-rpg-evidence-redaction-v1`. Нормативный envelope и порядок его полей:

```json
{
  "schemaVersion": "walking-rpg-device-validation-evidence-v1",
  "redactionPolicy": "walking-rpg-evidence-redaction-v1",
  "exportedAtUtc": "<RFC-3339 UTC>",
  "updatedAtUtc": "<RFC-3339 UTC>",
  "launch": {
    "startedAtUtc": "<RFC-3339 UTC>",
    "platform": "<android|ios>",
    "operatingSystemVersion": "<version>",
    "appVersion": "<version>",
    "buildNumber": "<build>",
    "sourceGitSha": "<40 lowercase hex characters>",
    "buildMode": "<debug|profile>",
    "authenticationMode": "<development|oidc>",
    "healthSource": "<healthkit|health_connect|development>"
  },
  "latestHealth": {
    "status": "<succeeded|failed|blocked>",
    "providerState": "<available|update_required|unavailable|not_applicable|unknown>",
    "permissionState": "<request_succeeded|denied|settings_required|restricted|not_required|unknown>",
    "authoritativeTotal": 0,
    "localDate": "<YYYY-MM-DD>",
    "timeZone": "<IANA timezone>",
    "includeManualEntries": false,
    "durationMs": 0,
    "errorCategory": null
  },
  "latestSync": {
    "status": "<succeeded|failed|blocked>",
    "acceptedTotal": 0,
    "acceptedDelta": 0,
    "energyGranted": 0,
    "energyBalanceAfter": 0,
    "economyVersion": 0,
    "stateVersion": 0,
    "riskStatus": "<ACCEPTED|NO_NEW_ACTIVITY|TOTAL_DECREASED>",
    "serverTime": "<RFC-3339 UTC>",
    "durationMs": 0,
    "errorCategory": null
  },
  "authoritativeCheckpoint": {
    "homeActivityStateVersion": 0,
    "homeEconomyVersion": 0,
    "platformStateVersion": 0,
    "contentVersion": "<content version>",
    "dailySteps": 0,
    "dailyGoal": 0,
    "availableEnergy": 0,
    "currentNodeId": "<server-owned content id>",
    "expeditionStatus": "<IN_PROGRESS|EVENT_READY|COMPLETED>",
    "expeditionProgress": 0,
    "hasPendingEventResult": false,
    "lastActivitySyncPresent": true,
    "totalAcceptedSteps": 0,
    "hasSuccessfulActivitySync": true,
    "resolvedEventCount": 0,
    "completedMilestones": [],
    "firstJourneyStage": "<welcome|activity|pet|expedition|event|complete>",
    "firstJourneyComplete": false,
    "homeServerTime": "<RFC-3339 UTC>",
    "platformServerTime": "<RFC-3339 UTC>",
    "durationMs": 0
  },
  "journal": [
    {
      "sequence": 1,
      "scenario": "<provider|permission|read|sync|checkpoint>",
      "outcome": "<passed|failed|blocked>",
      "startedAtUtc": "<RFC-3339 UTC>",
      "durationMs": 0,
      "errorCategory": null
    }
  ],
  "checksum": {
    "algorithm": "SHA-256",
    "value": "<64 lowercase hex characters>"
  }
}
```

`latestHealth`, `latestSync` и `authoritativeCheckpoint` могут быть `null`,
если соответствующая стадия ещё не достигнута. Неуспешные observations
содержат coarse `errorCategory`, а их поля успешного результата остаются
`null`.
Journal не является logging map: он содержит только шесть показанных полей,
а подробные facts допускаются только в трёх typed top-level observations.
Unknown/free-form поля не входят в schema v1.

Verifier также проверяет cross-field причинность: journal timestamps не
убывают; каждая известная Health action group имеет порядок
`provider → permission → read`; успешный sync опирается на последнюю
предшествующую успешную read group; typed observation совпадает с последней
соответствующей journal entry. Authoritative activity/event facts должны
воспроизводить сохранённые first-journey milestones. Для sync
`energyGranted` равен числу пересечённых 100-step порогов:
`acceptedTotal ~/ 100 - (acceptedTotal - acceptedDelta) ~/ 100`. Если в journal
есть `journal_limit_reached`, он единственный и последний; 64-я запись без
этого marker отклоняется.

`timeZone` принимается только как известная IANA area-form или legacy alias;
slash/path-подобная строка, dot-segment или endpoint не получает исключение из
redaction policy.

SHA-256 вычисляется по UTF-8 compact `jsonEncode(payload)`, где `payload`
содержит первые девять top-level полей в показанном insertion order — от
`schemaVersion` до `journal` — и не содержит `checksum`. Nested objects также
используют schema-defined order, а порядок journal/milestone arrays
сохраняется. Затем объект `checksum` добавляется последним. Verifier требует
exact compact canonical envelope, поэтому pretty-print, перестановка полей или
ручное редактирование отклоняются до сравнения digest. Проверку нужно выполнять
тем же schema-v1 codec, а не хешировать весь envelope как файл. Это контроль
целостности, а не подпись, attestation или доказательство личности тестировщика.

## Независимая проверка export

До переноса typed facts в ручной record reviewer запускает repository-owned
CLI из каталога `mobile`. Для принимаемого physical Health artifact все четыре
expected-параметра обязательны и берутся из approved candidate/inventory
record, а не из проверяемого JSON:

```bash
cd mobile
dart run tool/verify_device_validation_evidence.dart \
  --require-physical-health \
  --expect-source-git-sha "$EXPECTED_SOURCE_GIT_SHA" \
  --expect-app-version "$EXPECTED_APP_VERSION" \
  --expect-build-number "$EXPECTED_BUILD_NUMBER" \
  --expect-platform android \
  "$APPROVED_EVIDENCE_FILE"
```

Для iOS используется `--expect-platform ios`. CLI читает только regular-file
strict UTF-8 не больше 64 KiB, вызывает тот же
`DeviceValidationEvidenceCodec.verify`, который защищает mobile export, и
затем сверяет exact source/app/build/platform. Режим
`--require-physical-health` дополнительно отклоняет `development` source и
export без Health observation. В stdout попадает только allowlisted summary:
schema, candidate metadata, platform/Health source, число journal entries и
checksum; document body, OS string и arbitrary evidence values не печатаются.

Успешный CLI exit доказывает структуру, redaction/checksum и заявленную
candidate binding файла. Он не доказывает, что устройство физическое, что
сценарий выполнен человеком или что #21 закрыт: эти выводы требуют inventory,
ручного record, review и полного matrix evidence.

## Redaction workflow

До share exporter применяет allowlist и запрещает:

- raw HealthKit/Health Connect samples и timestamps отдельных samples;
- access/refresh/ID tokens, cookies и authorization headers;
- user/account/OIDC subject, device/installation, command, idempotency,
  diagnostics или crash identifiers;
- endpoint, hostname, URL, request/response body;
- абсолютные и относительные filesystem paths;
- provider source/record IDs, raw exception/error и произвольные notes.

Порядок работы тестировщика:

1. Завершить сценарий и проверить, что обязательные checkpoints присутствуют,
   а переполнение не отмечено.
2. Нажать явный export/share в Validation Center.
3. Приложение формирует JSON не более 64 KiB, считает checksum, создаёт один
   временный файл и открывает platform share sheet.
4. После возврата или ошибки share приложение пытается удалить временный файл
   в `finally`. Копия, выбранная тестировщиком в share sheet, живёт по правилам
   целевого хранилища.
5. До публикации reviewer запускает независимый CLI с exact candidate
   expectations, затем проверяет inventory/manual record и отсутствие
   запрещённых данных вне JSON.
6. Если нужна redaction или исправление, файл не редактируется вручную:
   причина устраняется и export создаётся заново. Иначе checksum и причинный
   журнал теряют доказательную ценность.
7. JSON прикладывается к заполненному
   `docs/evidence/health-device-validation-template.md` в одобренное внутреннее
   хранилище. Публичная issue/PR не является хранилищем raw evidence.

Удаление temporary-файла не удаляет уже переданную копию. Поэтому redaction
policy является основной границей, а cleanup — дополнительным сокращением
retention.

## Acceptance criteria

- backend high-watermark не уменьшается;
- один внутренний payload/key не создаёт две награды, при этом payload/key не
  попадает в evidence;
- два устройства не удваивают общий daily total;
- UI после свежего reload совпадает с server-authoritative state;
- cached state явно отличается от authoritative checkpoint;
- ошибки разрешений не ломают platform-журнал;
- JSON соответствует schema/redaction identifiers, exact source SHA, лимитам
  64 entries / 64 KiB и checksum;
- evidence не содержит raw health samples, secrets, user/account/device/
  command identifiers, endpoints или paths;
- заполненный шаблон явно различает `PASS`, `FAIL` и `BLOCKED` и содержит
  дату review.

Шаблон: `docs/evidence/health-device-validation-template.md`.
