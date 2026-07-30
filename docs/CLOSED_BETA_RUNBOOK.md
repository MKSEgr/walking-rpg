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

- onboarding completion;
- first-journey start rate и conversion до sync/ENERGY/pet/node/event;
- p50/p90 time-to-first-ENERGY, node, event и onboarding completion только по
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
только новые authoritative пары от `JOURNEY_STARTED`.

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

1. V10, новый backend и новый mobile выкатываются с
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
