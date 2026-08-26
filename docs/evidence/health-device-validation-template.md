# Health device validation evidence

> Этот файл — незаполненный шаблон, а не свидетельство выполненной проверки.
> До датированного прогона на физическом устройстве и review итог остаётся
> `EXTERNAL_VALIDATION_REQUIRED`.

## Идентификация прогона

- Дата/время начала UTC:
- Дата/время окончания UTC:
- Дата review UTC:
- Роль/категория внутренней группы без person/account ID (вне JSON):
- Сценарий и строка матрицы:
- Inventory schema: `walking-rpg-health-device-inventory-v1`
- Inventory record status: `RECORDED`
- Inventory slot ID:
- Inventory owner role category:
- Inventory evidence storage category без URL/path:
- [ ] Inventory прошёл `verify_health_device_inventory.py --require-recorded`
- [ ] Выбранная строка имеет `status=AVAILABLE`; `BLOCKED` не выдан за pass
- Source Git SHA (40 lowercase hex):
- App version/build:
- Platform и OS version:
- Device model без serial/device ID:
- Provider/watch category без source ID:
- IANA timezone и локальная дата:

Не записывать technical user/device/installation ID, OIDC subject, token,
idempotency key, endpoint, path или raw provider data ни в шаблон, ни в JSON.

## Предусловия

- Чистая установка / upgrade / restart:
- Health permission до начала:
- Provider/watch configuration:
- Исходный aggregated daily total:
- Исходный authoritative accepted total / wallet:
- Network/lifecycle condition:
- Validation Center включён в non-release build:
- SHA в UI/export совпадает с проверяемым commit:

## Schema-v1 artifact

- Evidence filename:
- Schema version: `walking-rpg-device-validation-evidence-v1`
- Redaction policy: `walking-rpg-evidence-redaction-v1`
- Размер UTF-8 JSON (не более 65 536 bytes):
- Journal entries (не более 64):
- Launch start из JSON:
- Export time из JSON:
- Updated time из JSON:
- Source SHA из JSON:
- App version/build из JSON:
- Platform/OS из JSON:
- Checksum algorithm: `SHA-256`
- Checksum из JSON:
- Пересчитанный checksum:
- CLI expected source SHA / app version / build / platform:
- CLI allowlisted summary сохранён без document body: да / нет
- [ ] Top-level keys и order совпадают со schema v1: `schemaVersion`,
      `redactionPolicy`, `exportedAtUtc`, `updatedAtUtc`, `launch`,
      `latestHealth`, `latestSync`, `authoritativeCheckpoint`, `journal`,
      `checksum`
- [ ] Checksum совпадает
- [ ] `verify_device_validation_evidence.dart --require-physical-health`
      прошёл со всеми четырьмя exact expected-параметрами candidate
- [ ] Temporary-файл удалён после возврата/ошибки share
- Категория одобренного хранилища без URL/path:

Checksum пересчитывается schema-v1 codec по compact JSON первых девяти
top-level полей в нормативном insertion order, без объекта `checksum`; нельзя
хешировать весь файл или переставлять поля. Он подтверждает только целостность
детерминированного payload и не является подписью, attestation или
доказательством выполнения сценария.

Команда reviewer-а запускается из `mobile` и получает expected values из
approved candidate/inventory record, а не из самого export:

```bash
dart run tool/verify_device_validation_evidence.dart \
  --require-physical-health \
  --expect-source-git-sha "$EXPECTED_SOURCE_GIT_SHA" \
  --expect-app-version "$EXPECTED_APP_VERSION" \
  --expect-build-number "$EXPECTED_BUILD_NUMBER" \
  --expect-platform "$EXPECTED_PLATFORM" \
  "$APPROVED_EVIDENCE_FILE"
```

Успешный результат не заменяет physical-device review и не переводит #21 в
`VALIDATED`.

## Проверка redaction

- [ ] Нет raw HealthKit/Health Connect samples и timestamps отдельных samples
- [ ] Нет access/refresh/ID tokens, cookies или authorization headers
- [ ] Нет user/account/subject/device/installation identifiers
- [ ] Нет command/idempotency/diagnostics/crash identifiers
- [ ] Нет provider record/source identifiers
- [ ] Нет hostname, endpoint, URL, request/response body
- [ ] Нет абсолютных/относительных filesystem paths
- [ ] Нет raw exception/error или произвольных diagnostic/notes fields
- [ ] JSON содержит только schema-v1 allowlisted поля
- [ ] Файл после export не редактировался вручную

При нарушении любого пункта artifact не распространять. Устранить источник
данных и сформировать новый export; ручная правка делает checksum невалидным.

## Checkpoints и факты

| № | UTC | Checkpoint | Outcome | Aggregated / authoritative facts | Ожидание | Результат |
|---|-----|------------|---------|----------------------------------|----------|-----------|
| 1 |     | Provider   |         |                                  |          |           |
| 2 |     | Permission |         |                                  |          |           |
| 3 |     | Read       |         |                                  |          |           |
| 4 |     | Sync       |         |                                  |          |           |
| 5 |     | Authoritative reload | |                                |          |           |

В таблицу переносить только обезличенные typed facts из JSON. Не вставлять
payload, key, raw response/error, URL, path или отдельные health samples.
Для permission значение `request_succeeded` означает, что platform request
завершился без ошибки, но не доказывает предоставление HealthKit read access.

## Проверка идемпотентности и authoritative state

- Aggregated total первого sync:
- `acceptedTotal` первого sync/reload:
- `energyGranted` первого sync:
- Wallet после первого authoritative reload:
- Aggregated total повторного sync:
- `acceptedTotal` повторного sync/reload:
- `energyGranted` повторного sync (ожидается `0` для того же total):
- Wallet после повторного authoritative reload:
- Cached state встречался: да / нет
- Если да, был ли он явно отделён от authoritative checkpoint:

## Lifecycle / battery

- Foreground/background duration:
- Resume behavior:
- Restart: отдельные evidence filenames и checksums:
- Permission revoke/regrant behavior:
- Midnight/timezone transition:
- Battery measurement interval и метод:
- Battery start/end:

Не переносить в это поле crash ID или raw diagnostics. Сбой описывается
обезличенной категорией и воспроизводимыми действиями.

## Отклонения и наблюдения

- Ожидаемый результат:
- Фактическое отклонение:
- Безопасная coarse failure category:
- Нужен повторный прогон: да / нет
- Статус/категория внутреннего defect без URL/ID и raw evidence:

## Итог

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Обоснование:

Reviewer role/group category без person/account ID:

Следующее действие:
