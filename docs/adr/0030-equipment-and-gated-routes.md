# ADR 0030: server-authoritative equipment и gated routes

- **Статус:** Accepted
- **Дата:** 2026-08-01

## Контекст

`resonance-compass`, созданный первым рецептом, имел persistent identity, но не
влиял на игровой выбор. Клиент не должен самостоятельно объявлять предмет
экипированным или открывать маршрут: stale/modified mobile мог бы использовать
чужой instance, обойти prerequisite либо разойтись со вторым устройством.

Новая мутация должна сохранять уже принятые границы: account deletion,
idempotent replay, durable event-result handoff, server-owned content и
additive rolling contract. Потерянный успешный response обязан replay-иться
даже если позднее появился pending event receipt.

## Решение

### Equipment content и API

Backend владеет content version `equipment-v1`. В первой версии есть один slot
`NAVIGATION`; единственный допустимый item — unique `resonance-compass`.

```text
POST /api/v1/equipment/slots/{slotId}/equip
POST /api/v1/equipment/slots/{slotId}/unequip
```

Equip принимает только `itemInstanceId` и `idempotencyKey`; unequip принимает
только `idempotencyKey`. Имя, тип, эффект и допустимый slot клиент не задаёт.
Identity всегда берётся из authenticated context.

### Transaction и concurrency

Новая equipment-команда выполняется одной транзакцией:

```text
account-deletion lock + active-subject check
→ user-scoped equipment advisory lock
→ exact idempotency lookup
→ shared user+starter-expedition advisory lock
→ pending event-result guard
→ owned unique item lock + server content validation
→ desired slot state mutation
→ immutable processed response
```

Exact replay находится до expedition boundary: потерянный response доступен и
после появления pending receipt. Новая мутация получает тот же expedition lock,
что advance/event resolution/crafting, и после него проверяет durable receipt.
Это исключает изменение loadout между commit результата и обязательным ACK.

Event resolution сначала получает expedition lock и только читает equipment;
он не получает equipment advisory lock. Поэтому порядок не образует цикл:
event, уже владеющий expedition boundary, видит предыдущее committed состояние,
а equipment-команда ждёт его commit. Если equipment получил boundary первым,
event увидит новое committed состояние.

Повтор желаемого состояния с новым key разрешён и возвращает `changed=false`
без увеличения slot version. Повтор исходного key возвращает полный исходный
response. Тот же key с другим action/item получает idempotency conflict.

### Storage и ownership

Flyway V14 добавляет:

- `equipment_slot_state` с version, nullable item instance и composite FK
  `(user_id, item_instance_id)` на принадлежащий пользователю unique item;
- partial unique index, не позволяющий одному item instance занимать несколько
  slots;
- `processed_equipment_command` с fingerprint и immutable response snapshot.

Обе таблицы каскадно удаляются с `app_user`, входят в account export и exact
synthetic backup/restore manifest. Account-deletion lock удерживается до commit,
поэтому deletion не пересекается с replay или slot mutation.

### Gated nonlinear route

Content `chapter-1-v2` сохраняет 18 основных узлов и добавляет опциональный
`resonance-pocket`. В событии `mirror-delta-v1` выбор `follow-resonance`
доступен только при экипированном `resonance-compass` в `NAVIGATION` и ведёт в
опциональный узел; обычные choices продолжают вести прямо в `storm-archive`.
Событие опционального узла также возвращает игрока в `storm-archive`.

V14 только создаёт `chapter-1-v2` как inactive release и сохраняет
`chapter-1-v1` активной. Это обязательная rolling-deploy граница: новый backend
до cluster-wide активации возвращает v1/18 nodes, целиком исключает
`follow-resonance` и из `choices`, и из `lockedChoices`, а прямую новую
resolution-команду отклоняет как неизвестный choice. После drain всех старых
backend instances оператор активирует уже подготовленную v2 через существующий
admin content-release API. Home и event resolution читают один durable
`content_release` flag внутри своей транзакции.

Exact replay проверяется до activation gate. Поэтому уже сохранённый v2 result
остаётся воспроизводимым, даже если флаг позднее изменён. Откат на backend,
который не знает `resonance-pocket`, после первой сохранённой
`follow-resonance` resolution запрещён: требуется forward fix. Полная
последовательность активации и контрольные запросы описаны в
[production runbook](../PRODUCTION_OPERATIONS_RUNBOOK.md#chapter-1-v2-activation).

`GET /home` возвращает additive projections:

- `equipment[]` со slot state и nullable item;
- unique inventory identity, equippable/equipped slot IDs;
- доступные `choices`, а также additive `lockedChoices` с `availability` и
  nullable server-owned `requirement`.

Availability в home нужна для UX, но не является authorization boundary.
Event resolution повторно проверяет authoritative equipment под expedition
lock и возвращает `EVENT_CHOICE_UNAVAILABLE`, если prerequisite отсутствует.
Locked choice не попадает в legacy `choices`: старый mobile игнорирует новое
поле `lockedChoices` и поэтому остаётся на основном маршруте вместо показа
неработающей кнопки. Новый mobile объединяет оба массива только для UI.

### Mobile

Flutter сохраняет `EQUIPMENT` в существующей GAMEPLAY lane до первой сетевой
попытки. Payload содержит только slot/action/item instance; restart replay
использует исходный key. Cached home и home с pending event result остаются
read-only. После success read cache инвалидируется и выполняется authoritative
reload; optimistic slot state или route unlock не создаются.

## Последствия

Плюсы:

- crafted unique item получает проверяемую игровую ценность;
- чужой item instance и client-forged route prerequisite отклоняются;
- equip/unequip безопасны при retry, restart, multi-device и account deletion;
- первая нелинейная ветка не ломает основной маршрут или старый mobile;
- staged content release не позволяет старому backend получить новый node;
- home, export/delete и backup/restore отражают новый persistent state.

Ограничения:

- реализован один slot и один equippable item;
- нет stats, rarity, upgrades, durability или loadout presets;
- баланс optional rewards требует beta validation;
- старый mobile игнорирует equipment projection и использует только основной
  маршрут.

## Отклонённые альтернативы

### Хранить equipped-флаг только на mobile

Отклонено: состояние расходится между устройствами и не защищает event API.

### Передавать itemId вместо item instance

Отклонено: instance ownership нельзя доказать, а будущие per-item attributes
потребуют несовместимой смены identity.

### Скрывать locked choice и не проверять его на backend

Отклонено: UI visibility не является security boundary; прямой API-вызов
обошёл бы prerequisite.

### Активировать `chapter-1-v2` прямо в V14

Отклонено: при rolling deploy старый backend может получить сохранённый
`resonance-pocket`, которого нет в его content graph, или отвергнуть новый
choice. Schema migration только stage-ит release; отдельная активация после
cluster drain является частью совместимости, а не необязательной операционной
рекомендацией.

### Вставить optional node в последовательный список

Отклонено: обычные choices не должны случайно менять маршрут. Переход хранится
как явный override пары `eventId + choiceId`.
