# Closed beta runbook

Closed beta начинается только после подписанного `EXPAND` по
[internal-alpha protocol](INTERNAL_ALPHA_PROTOCOL.md) и не может использовать
неподписанный template, `FIX_AND_RERUN` или `STOP` как go-gate.

## До набора участников

- release candidate прошёл standard CI и Release quality;
- физическая device matrix имеет evidence;
- privacy/store declarations опубликованы;
- crash ingestion и retention read model доступны;
- определены owner, support channel и incident window.

Backend operational topology, ingress limits, timeouts и synthetic
backup/restore procedure описаны в
[`PRODUCTION_OPERATIONS_RUNBOOK.md`](PRODUCTION_OPERATIONS_RUNBOOK.md).
Synthetic evidence не заменяет deployed monitoring или restore реального
backup.

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
- resonance compass recipe-seen → ready → crafted → equipped conversion;
- mirror-delta reached → route locked/available → chosen → completed
  conversion;
- compass instrumentation rate, out-of-order pairs и authoritative targets
  без instrumented baseline;
- support incidents.

Telemetry-вклад в D1/D7/D30 определяется по server receipt time. Поле
`occurredAt` остаётся client-reported диагностикой и не используется для выбора
retention day; поэтому часы устройства или отложенная доставка не должны
выдаваться за server-confirmed возврат пользователя. Counters одного ответа
строятся из единого PostgreSQL snapshot. V16 index
`(platform_event.user_id, platform_event.received_at)` должен быть применён до
использования retention endpoint на накопленной telemetry history.

Срез доступен через
`GET /api/v1/admin/platform/analytics/first-journey?cohortCode=...`.
`reachedUsers` может включать legacy backfill; временные percentiles используют
только новые authoritative пары от `JOURNEY_STARTED`. Для финальной
delivery-completion используется stage
`FIRST_EVENT_RESULT_ACKNOWLEDGED`, а не `ONBOARDING_COMPLETED`: legacy
auto-ACK виден в `conversionFromStarted` как continuity `BACKFILLED`, но не
входит в `authoritativeConversionFromStarted` и p50/p90. Для explicit alpha
ACK rate используется именно authoritative conversion.

Compass-срез доступен через
`GET /api/v1/admin/platform/analytics/compass-journey?cohortCode=...`.
Для beta-решения `cohortCode` обязателен организационно, даже если endpoint
разрешает общий диагностический срез. Вместе с JSON фиксируются exact build,
период наблюдения, число приглашённых/активных и время `generatedAt`.
Эта метка приходит из первого PostgreSQL statement и обозначает границу
единого `REPEATABLE_READ` snapshot, а не время завершения HTTP-ответа.

## Как читать compass funnel

`RECIPE_SEEN`, `RECIPE_READY_SEEN`, `ROUTE_LOCKED_SEEN` и
`ROUTE_AVAILABLE_SEEN` — client-reported viewport exposure card из свежего
network Home при текущей foreground route. Они помечены `CLIENT_REPORTED` и
доказывают доставку canonical telemetry, но не самостоятельный игровой
результат или точный render timestamp. Остальные stages выводятся из immutable
craft/equipment/expedition/event receipts и имеют source `AUTHORITATIVE`.

Route baseline дополнительно привязан к фактическому
immutable `content_release.activated_at` активной `chapter-1-v2`: ожидавшие на Mirror Delta
стартуют в момент активации, достигшие позже — в момент receipt, а resolved до
активации legacy events исключены. Перед сравнением route conversion
зафиксируйте activation timestamp вместе с build/period. Повторный publish той
же версии меняет `created_at`, но не начинает funnel заново.

Порядок чтения среза:

1. проверить `instrumentationRate`; низкое покрытие не позволяет сравнивать
   conversion между build-ами;
2. проверить `*TargetsWithoutStartUsers`: это признак старого клиента,
   существующего до instrumentation progress или неполной доставки telemetry;
3. проверить `outOfOrderPairs`: offline delivery или пользователь, уже
   прошедший stage до первого instrumented Home, учитывается в conversion, но
   исключается из latency;
4. сравнивать `conversionFromStarted` и `orderedConversionFromStarted`, не
   смешивая их смысл;
5. для продуктовых решений использовать прежде всего authoritative
   `COMPASS_CRAFTED`, `COMPASS_EQUIPPED`, `RESONANCE_ROUTE_CHOSEN` и
   `RESONANCE_ROUTE_COMPLETED`, а причину разрыва подтверждать support/
   interview evidence.

Endpoint возвращает cumulative first-user-stage snapshot, а не временной
ряд. Для сравнения build-ов нужны раздельные cohorts или заранее
зафиксированные периоды; один поздний cumulative срез нельзя выдавать за A/B
результат. Реализация analytics не закрывает Milestone 10–13 beta gates без
реальных данных и принятого owner-ом evidence.

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
- устойчивый рост `413/429`, saturation readiness или недоступность
  management probes;
- неверная обработка health totals/permissions;
- риск утечки данных;
- рост `BLOCK/REVIEW` без подтверждённого fraud;
- резкое падение compass `instrumentationRate` после rollout;
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
