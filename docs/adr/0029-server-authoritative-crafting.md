# ADR 0029: server-authoritative crafting и unique inventory

- **Статус:** Accepted
- **Дата:** 2026-08-01

## Контекст

После событий первой главы у пользователя остаются stackable materials, но до
этого решения они были только накопительной наградой. Клиент не должен сам
решать, какие материалы списать и какой предмет выдать: это позволило бы
подменять стоимость, повторять награду после потери ответа и расходиться с
authoritative inventory между устройствами.

Существующий `inventory_ledger` был рассчитан только на положительные event
rewards. Для первого material sink нужны отрицательные audit-записи,
неотрицательный итоговый stack, атомарная проверка нескольких ingredients и
non-stackable item instance. При этом rolling mobile/backend upgrade должен
оставаться additive: старый mobile игнорирует новую home projection, а новый
mobile принимает home старого backend без неё.

## Решение

### Versioned recipe content

Backend владеет независимой версией crafting content `crafting-v1`. Первый
рецепт имеет стабильный ID `resonance-compass-v1`:

```text
2 × lumen-shard + 1 × echo-thread
→ 1 × resonance-compass (UNIQUE)
```

Recipe definition содержит version, отображаемые имя/описание, material
ingredients и unique result. Request принимает только `recipeId` из path и
`idempotencyKey`; quantity, item name, cost и result от клиента запрещены
самой формой API.

### Transaction и concurrency

`POST /api/v1/crafting/recipes/{recipeId}/craft` выполняется одной
транзакцией:

```text
account-deletion lock + active-subject check
→ user-scoped crafting advisory transaction lock
→ exact idempotency lookup
→ shared user+starter-expedition advisory transaction lock
→ pending event-result guard
→ server recipe lookup
→ unique result absence check
→ material rows FOR UPDATE в стабильном itemId-порядке
→ проверка всех ingredients
→ debit каждого stack + append-only ledger
→ unique item insert
→ immutable command/ingredient response insert
```

Account-deletion lock удерживается до commit, поэтому удаление аккаунта не может
пересечься с replay lookup или inventory mutation. Проверка shortage завершается
до первой мутации. Любая поздняя ошибка
откатывает все debit, ledger, unique item и processed response. User lock с
отдельным namespace сериализует competing craft-команды одного владельца;
stable row order снижает риск deadlock с другими inventory mutations.

Exact replay выполняется до expedition boundary и поэтому остаётся доступен при
последующем pending receipt. Новая craft-команда разделяет user+expedition lock
с advance/event resolution и после его получения проверяет durable pending
result. Это исключает material debit между commit результата события и его
обязательным handoff/ACK, включая stale-home и queued-command сценарии.

Исходный scope `userId + recipeId + idempotencyKey` хранит SHA-256 fingerprint
и полный response snapshot. Exact replay возвращает тот же item instance,
ingredient quantities/versions и timestamps. Другой key после уже созданного
unique result получает `CRAFT_ALREADY_COMPLETED` до debit.

### Inventory schema

Flyway V13 заменяет reward-only checks `inventory_ledger` на:

```text
quantity_delta <> 0
quantity_after >= 0
```

Event reward path по-прежнему принимает только положительный stackable
`MATERIAL`; отрицательные записи создаёт только crafting consumption path.
`unique_inventory_item` хранит UUID instance, stable item/recipe IDs, recipe
version и `crafted_at`. Уникальность закреплена по `user + item` и
`user + recipe`.

`processed_crafting_command` хранит immutable result snapshot, а
`processed_crafting_ingredient` — точные consumed/after/version значения для
каждого ingredient. Эти snapshots не реконструируются из текущего inventory
при replay.

### Home и mobile

`GET /home` объединяет material stacks и unique items в additive `inventory`
с `kind=MATERIAL|UNIQUE`. Отдельный additive `craftingRecipes` проецирует
server recipe, ingredients, available quantities, result preview и один из
статусов:

```text
READY
MISSING_MATERIALS
CRAFTED
```

Home читает state в `REPEATABLE_READ`, поэтому inventory и recipe status
относятся к одному snapshot. Flutter не рассчитывает recipe readiness локально.

Mobile сохраняет `CRAFTING` command в существующей GAMEPLAY lane до первой
сетевой попытки. Payload содержит только `recipeId`, а retry/restart использует
исходный key. Cached home и home с pending event result не разрешают craft.
После success read cache инвалидируется и выполняется authoritative reload;
optimistic material debit или unique item insert отсутствуют.

### Account data и operations

Unique inventory и immutable crafting snapshots являются account-scoped
данными. Они входят в JSON export, удаляются каскадом с `app_user` и покрыты
synthetic backup/restore fixture и exact manifest verifier V13. Export не
включает access tokens или локальный mobile outbox.

## Последствия

Плюсы:

- material sink защищён той же server-authoritative моделью, что ENERGY и
  event rewards;
- потеря response и process restart не создают второй item или debit;
- partial craft и отрицательный inventory balance запрещены транзакцией/БД;
- unique item имеет собственную persistent identity;
- старый/new mobile/backend rolling contract остаётся additive;
- account export/delete и backup/restore не забывают новый state.

Ограничения:

- реализован один starter recipe без rarity, upgrades, dismantling или recipe
  CMS;
- unique item пока имеет только content snapshot в home, без отдельного detail
  endpoint;
- стоимость рецепта требует beta/economy validation и не считается
  подтверждённой synthetic tests;
- ручные corrections/compensations inventory не вводятся этим решением.

## Отклонённые альтернативы

### Crafting на клиенте

Отклонено: client-controlled cost/result ломает authoritative economy и не
защищает multi-device/retry сценарий.

### Представлять unique item как stack quantity 1

Отклонено: stack не даёт instance identity и затрудняет дальнейшие per-item
attributes/upgrades. Home может объединить projections без объединения storage
semantics.

### Удалять ledger rows при consumption

Отклонено: текущая проекция stack не заменяет audit trail. Credit и debit
остаются append-only, а balance защищается `quantity_after >= 0`.

### Списывать ingredients по очереди без общей проверки

Отклонено: shortage второго ingredient не должен оставлять частичный debit.
Все checks и mutations входят в одну transaction boundary.
