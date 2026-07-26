# ADR 0014: второй узел стартовой экспедиции и постоянный материальный инвентарь

- **Статус:** Accepted
- **Дата:** 2026-07-26

## Контекст

Первая версия игрового цикла завершалась сразу после разрешения `signal-source-v1`. Пользователь получал XP пилота и bond питомца, а экспедиция переходила в `COMPLETED`. Для проверки повторяемого контентного цикла требовалось продолжить ту же экспедицию ещё одним узлом и добавить награду, отличную от числового progression.

При этом уже существовали пользователи со всеми промежуточными состояниями `starter-v1`:

```text
IN_PROGRESS первого узла
EVENT_READY первого события
COMPLETED после первого события
```

Обновление не должно терять их progression, повторно выдавать награду или ломать сохранённые идемпотентные ответы.

## Решение

### Starter content v2

`starter-expedition-v1` сохраняет стабильный идентификатор, но получает `contentVersion = starter-v2` и два последовательных узла:

```text
outer-beacon (30 ENERGY)
→ signal-source-v1
→ lumen-gate (45 ENERGY)
→ echo-vault-v1
→ COMPLETED
```

Разрешение первого события больше не завершает экспедицию. Оно атомарно переводит состояние на `lumen-gate` с нулевым progress и status `IN_PROGRESS`.

### Второе событие

`echo-vault-v1` имеет два server-owned выбора:

```text
stabilize-core
  +30 pilot XP
  +8 pet bond
  +2 lumen-shard

follow-echo
  +20 pilot XP
  +18 pet bond
  +1 echo-thread
```

После разрешения второго события экспедиция получает `COMPLETED`.

### Inventory

Вводятся две таблицы:

```text
inventory_stack   — текущая проекция количества item пользователя
inventory_ledger  — append-only журнал положительных material reward
```

Первый source type:

```text
reasonCode = EVENT_MATERIAL_REWARD
sourceType = EVENT_RESOLUTION
```

Одна комбинация `userId + sourceType + sourceKey` может создать только одну material reward. Повтор исходного event command возвращает сохранённый response и не меняет stack повторно.

Названия и описания starter item остаются server-owned content. В stack хранится стабильный `itemId`, количество и версия. Immutable event response хранит snapshot имени, описания и количества после исходной операции.

### Транзакция

Разрешение события выполняет одним commit:

```text
проверка event idempotency
→ progression reward
→ inventory stack update
→ inventory ledger insert
→ expedition transition/completion
→ processed event response
```

Любая поздняя ошибка откатывает все изменения.

### Миграция starter-v1

Flyway V5:

1. расширяет immutable event response nullable material snapshot;
2. создаёт inventory stack и ledger;
3. переводит только консистентно завершённых пользователей первого цикла на `lumen-gate`;
4. сохраняет исторический `processed_event_resolution` первого события без изменения;
5. не создаёт inventory reward задним числом.

Пользователи в `IN_PROGRESS` и `EVENT_READY` первого узла продолжают его по новой логике. Пользователи с `COMPLETED` и подтверждённым историческим resolution начинают второй узел с сохранёнными XP/bond.

## Последствия

Плюсы:

- доказан повторяемый цикл «узел → событие → следующий узел»;
- материальная награда переживает restart;
- material reward защищена на command- и ledger-уровнях;
- старые пользователи продолжают игру без повторной выдачи;
- `GET /home` остаётся единственным authoritative read-model для mobile;
- durable outbox не требует нового command type: event resolution уже универсален по `eventId` и `choiceId`.

Ограничения:

- поддерживается только начисление stackable material;
- расход предметов, лимиты stack, rarity и crafting отсутствуют;
- starter content остаётся в Java-коде;
- после второго события нет следующего узла;
- отдельного inventory endpoint пока нет — inventory читается через `GET /home`.

## Условия пересмотра

Решение пересматривается перед появлением хотя бы одного из следующих требований:

- расход или обмен предметов;
- уникальные non-stackable item instances;
- server-driven content/CMS;
- несколько параллельных экспедиций;
- компенсационные операции или ручные inventory corrections;
- отдельная история inventory для пользователя или поддержки.
