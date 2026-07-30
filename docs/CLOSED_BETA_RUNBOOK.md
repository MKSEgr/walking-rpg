# Closed beta runbook

## До набора участников

- release candidate прошёл standard CI и Release quality;
- физическая device matrix имеет evidence;
- privacy/store declarations опубликованы;
- crash ingestion и retention read model доступны;
- определены owner, support channel и incident window.

## Cohorts

Начинать с внутреннего cohort и расширять ступенчато. Для каждого этапа фиксируются build, число приглашённых и активных, дата старта и stop conditions.

## Метрики

- platform onboarding completion;
- first-journey start rate и conversion до sync/ENERGY/pet/node/event/result
  ACK;
- p50/p90 time-to-first-ENERGY, node, event и explicit result-ACK только по
  authoritative milestones;
- доля migration-backfilled milestone records как data-quality caveat;
- D1/D7/D30 retention;
- activity sync success/retry rate;
- duplicate/idempotency conflicts;
- crash-free sessions/users;
- risk decision distribution и false positives;
- weekly route/quest completion;
- support incidents.

Срез доступен через
`GET /api/v1/admin/platform/analytics/first-journey?cohortCode=...`.
`reachedUsers` может включать legacy backfill; временные percentiles используют
только новые authoritative пары от `JOURNEY_STARTED`. Для финальной
delivery-completion используется stage
`FIRST_EVENT_RESULT_ACKNOWLEDGED`, а не `ONBOARDING_COMPLETED`: legacy
auto-ACK виден в `conversionFromStarted` как continuity `BACKFILLED`, но не
входит в `authoritativeConversionFromStarted` и p50/p90. Для explicit alpha
ACK rate используется именно authoritative conversion.

## Поддержка сохранённых действий

Если пользователь сообщает о зависшем выборе, награде или синхронизации:

1. попросить открыть **«Сохранённые действия»** из home, путевого журнала или
   аккаунта;
2. зафиксировать build, платформу и только счётчики `PENDING`/`FAILED` или
   состояние ошибки чтения;
3. для `PENDING` предложить восстановить сеть и нажать
   **«Повторить ожидающие действия»**;
4. после успеха убедиться, что экран перечитал server state;
5. `FAILED` не повторять вслепую: вернуться к свежему server state и создать
   новое пользовательское действие, если оно всё ещё допустимо;
6. dismiss `FAILED` удаляет только локальную диагностику и не отменяет
   backend mutation.

Обычный reload/resume экрана не является повторной отправкой: startup replay
выполняется один раз на authenticated runtime. Для следующей попытки в той же
сессии использовать только явную кнопку Recovery.

Не запрашивать screenshot/raw export с payload, idempotency key, receipt,
Health cursor, token или filesystem path. При corruption не советовать reset
или переустановку до сохранения incident evidence и отдельного решения owner:
непрочитанная `PENDING` запись может соответствовать уже выполненной server
mutation.

## Stop conditions

- потеря или дублирование экономики;
- массовый crash или невозможность старта;
- неверная обработка health totals/permissions;
- риск утечки данных;
- рост `BLOCK/REVIEW` без подтверждённого fraud;
- невозможность экспортировать или удалить аккаунт.

## Rollback

Остановить расширение cohort, отключить рискованные функции remote config,
отозвать build, сохранить immutable evidence и выпустить исправление отдельным
PR с новым build number.

Durable event-result handoff имеет отдельную безопасную последовательность:

1. Flyway V10–V11, новый backend и новый mobile выкатываются с
   `DURABLE_EVENT_RESULT_HANDOFF_ENABLED=false`;
2. старые backend instances полностью drain-ятся;
3. только новый backend pool получает `...=true`;
4. перед rollback gate снова выключается на всём пуле;
5. rollback binary разрешён только после `count(*) = 0`:

```sql
SELECT count(*)
FROM processed_event_resolution
WHERE handoff_required
  AND acknowledged_at IS NULL;
```

Старый backend нельзя смешивать с новым pool после activation. Если pending не
дренируется, выполняется forward fix совместимым binary, а не unsafe rollback.
