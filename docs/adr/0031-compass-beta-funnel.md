# ADR 0031: compass beta funnel и authoritative gameplay stages

- **Статус:** Accepted
- **Дата:** 2026-08-01

## Контекст

После server-authoritative crafting и equipment код позволяет пройти путь
`recipe → compass → equip → resonance route`, но внешние gates Milestone 10–11
нельзя закрыть synthetic fixtures. Нужен cohort read model, который показывает
не только конечные mutations, но и UX-разрывы: видел ли пользователь рецепт,
был ли он готов, заметил ли locked/available route.

Client способен сообщить показ, но не должен объявлять предмет созданным,
экипированным или маршрут завершённым. Cached/offline snapshot не является
новым показом. Доставка telemetry может произойти позднее gameplay mutation,
поэтому отрицательные интервалы нельзя смешивать с time-to-value. Read model
должен оставаться агрегированным, cohort-filtered и согласованным между всеми
запросами одного ответа.

## Решение

### Canonical impression command

Используется существующий idempotent endpoint platform commands с новым типом
`RECORD_COMPASS_IMPRESSION`. Payload содержит только enum `impression` и
`contentVersion` фактически полученного network Home. Backend:

- принимает только пять известных recipe/route состояний;
- сам подставляет stable recipe/event/choice IDs и contract version
  `compass-beta-funnel-v1`;
- использует server receive time, не client timestamp;
- отклоняет route impression, пока `chapter-1-v2` не активна cluster-wide;
- обходит reconciliation/persistence `roadmap_user_state`, поэтому не
  материализует новые progress facts и не меняет `stateVersion`;
- выполняет exact replay до release gate и не пишет второе событие.

Public `/telemetry/events` отклоняет оба зарезервированных compass event name
до `ensureUser`/INSERT. Иначе authenticated client мог бы записать тот же name
с произвольным `occurredAt` и исказить earliest stage/timing в общей
`platform_event`.

Recipe states записываются как `compass_recipe_impression`, route states — как
`compass_route_impression` в существующую `platform_event`. Это
`CLIENT_REPORTED`: canonical envelope уменьшает произвольность payload, но не
превращает показ в gameplay truth.

### Mobile delivery boundary

Только свежий network Home планирует impression, когда соответствующая
recipe/event card пересекает viewport, Home выбрана, её `ModalRoute` текущая и
приложение находится в `resumed`. Cached snapshot ничего не отправляет.
Accepted snapshot сохраняется при переключении destination, covering route или
background и проверяется снова после возврата. Детерминированный key включает
content version, content identity и состояние; повторный reload не создаёт
новый event, а изменение READY→CRAFTED/LOCKED→AVAILABLE получает отдельный key.
Завершившийся superseded request сверяется с monotonic request generation и не
создаёт impression для snapshot, который текущий FutureBuilder уже отбросил.

Команда хранится в существующем durable outbox как `TELEMETRY`. Она не
инвалидирует Home/Platform cache, не применяет optimistic state и не задерживает
порядок `ACTIVITY → GAMEPLAY`. Retry использует исходные payload/key.

### Funnel stages

Read model возвращает два funnel-а:

| Funnel | Baseline | Target stages |
|---|---|---|
| Crafting/equipment | client `RECIPE_SEEN` | client `RECIPE_READY_SEEN`; authoritative `COMPASS_CRAFTED`, `COMPASS_EQUIPPED` |
| Resonance route | authoritative `MIRROR_DELTA_REACHED`, не раньше активации v2 | client `ROUTE_LOCKED_SEEN`, `ROUTE_AVAILABLE_SEEN`; authoritative `RESONANCE_ROUTE_CHOSEN`, `RESONANCE_ROUTE_COMPLETED` |

Authoritative stages выводятся только из существующих persistent rows:

- `unique_inventory_item`;
- успешный `processed_equipment_command` action `EQUIP`;
- `processed_expedition_advance` с mirror event;
- `processed_event_resolution` для gated choice и optional route event.

Route baseline существует только при активной `chapter-1-v2`. Для пользователя,
который уже ожидал на Mirror Delta, baseline равен времени активации; для
достигшего событие позже — времени receipt. Resolution Mirror Delta до
активации исключает пользователя: legacy-выбор уже нельзя заменить новым
route-choice. Время берётся из immutable `content_release.activated_at`, а не
из mutable publish timestamp. Поэтому staged migration time, same-version
republish и старые завершённые события не сдвигают denominator или latency.

Client payload не может создать ни одну из этих стадий.

### Snapshot и timing semantics

Admin endpoint
`GET /api/v1/admin/platform/analytics/compass-journey?cohortCode=...` строит
ответ одной read-only `REPEATABLE_READ` транзакцией. Eligible users и cohort
membership следуют first-journey analytics. Ответ агрегирован и не содержит
user IDs.

`reachedUsers` считает target у started user независимо от порядка timestamps.
`orderedUsers`, p50 и p90 требуют `target >= baseline`. Отрицательная пара
остаётся в `outOfOrderUsers`, а authoritative target без baseline — в
`*TargetsWithoutStartUsers`. Это позволяет видеть старый client/offline delay,
не превращая его в отрицательный time-to-value.

`instrumentedUsers` и source counters позволяют оценить coverage. Наличие
endpoint-а или высокий synthetic conversion не является beta validation:
решение обязано фиксировать cohort, exact build, период и data-quality caveats.

### Storage и производительность

Новая gameplay/analytics таблица не добавляется. Flyway V15 отделяет nullable
`content_release.activated_at` от mutable `created_at`: активная версия обязана
иметь timestamp, первая активация staged row заполняет его, а trigger запрещает
перезапись. Стандартный V14 state автоматически переносит только seeded v1;
если v2 успели активировать или повторно опубликовать до V15, migration не
угадывает утраченное время по `created_at`, а требует явный timestamp из
immutable rollout/audit evidence и останавливается при его отсутствии. Legacy
resolution остаётся в immutable event receipt. Для закрытой
beta 50–500 участников существующие event-name/time и user/created-at индексы
достаточны, а release metadata и gameplay receipts уже входят в backup
boundary.
Если фактический объём или query latency выйдет за operational budget,
материализованная projection/index рассматривается отдельным измеренным
решением.

## Последствия

Плюсы:

- beta видит UX-разрывы, не доверяя client-у gameplay outcome;
- late/offline telemetry не искажает latency молча;
- instrumentation failure не блокирует игру и не меняет cache;
- staged v2 нельзя выдать за реально показанный route до активации;
- read model не дублирует persistent gameplay state; schema change ограничена
  immutable activation metadata существующего release row.

Ограничения:

- client impression остаётся недоверенным и измеряет server receipt после
  viewport exposure, а не точный timestamp отрисовки;
- cumulative snapshot не является временным рядом или готовым A/B analysis;
- пользователи, прошедшие путь до instrumentation, попадут в quality gaps;
- пороги conversion и продуктовые выводы требуют реального cohort evidence.

## Отклонённые альтернативы

### Отправлять все стадии с mobile

Отклонено: modified/stale client мог бы объявить craft, equip или completion
без соответствующей server mutation.

### Выводить показы из факта наличия кнопки на backend

Отклонено: server projection не доказывает, что network response дошёл до UI;
cached response также нельзя считать новым показом.

### Использовать client timestamp как latency truth

Отклонено: часы устройства и offline queue не являются доверенной общей
шкалой. Server receive time плюс явный out-of-order counter дают проверяемую
семантику.

### Сразу создать отдельную analytics schema/materialized view

Отклонено до измерения: для закрытой beta это преждевременная дубликация
источников и дополнительная migration/retention boundary.
