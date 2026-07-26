# ADR 0012: Foreground durable mobile command outbox

- Статус: принято
- Дата: 2026-07-26

## Контекст

Backend уже обеспечивает persistent idempotency для трёх изменяющих состояние команд:

```text
POST /api/v1/activity/sync
POST /api/v1/expeditions/{expeditionId}/advance
POST /api/v1/events/{eventId}/resolve
```

До этого mobile сохранял idempotency key только в памяти. Сценарий
`server commit → потерянный response → завершение процесса` приводил к тому, что после нового запуска клиент мог отправить тот же business action с новым key. Backend high-watermark защищал activity sync, но для debit ENERGY и event reward клиентская сторона не использовала всю силу серверного exact replay.

Нужен небольшой надёжный контур без фонового worker-а, отдельной БД и инфраструктуры, которую пока некому сопровождать.

## Решение

Добавить foreground durable outbox в Flutter-приложение.

Перед первой сетевой попыткой mobile сохраняет:

```text
ownerId
command type и lane
полный business payload
idempotency key
semantic fingerprint
created/updated timestamps
attempt count и последнюю ошибку
```

Команда удаляется только после успешного HTTP response и успешного преобразования response в domain result. Если приложение завершается после server commit, но до локального удаления, следующий запуск повторяет тот же payload с тем же key и получает сохранённый backend response snapshot.

## Хранилище

Используется versioned JSON envelope в application-support directory:

```json
{
  "version": 1,
  "commands": []
}
```

Запись выполняется через файл `.tmp`, предыдущая версия временно хранится как `.bak`. При запуске порядок восстановления такой:

1. committed target;
2. валидный temporary replacement;
3. backup.

Повреждённый target переименовывается в диагностический `.corrupt-*`. Если ни одна копия не читается, store возвращает ошибку и не затирает данные пустой очередью.

`shared_preferences` не используется: outbox содержит критичное состояние, для которого требуется контролируемая файловая запись и восстановление.

## Lanes и порядок

Команды разделены на две независимые lane:

```text
ACTIVITY — activity sync
GAMEPLAY — expedition advance и event resolution
```

Внутри lane используется FIFO. Retryable failure блокирует только последующие команды той же lane. Например, временная ошибка expedition не мешает синхронизации шагов.

Это не означает параллельную модификацию одного игрового aggregate: все gameplay-команды остаются последовательно упорядоченными.

## Классификация ошибок

Остаются `PENDING`:

- network/transport failures;
- `408`;
- `429`;
- `5xx`;
- успешный HTTP status с неоднозначным или некорректным response body.

Переходят в terminal `FAILED`:

- подтверждённые остальные `4xx`;
- некорректный сохранённый payload;
- локальная argument validation failure.

Terminal-команда сохраняется для диагностики, но не блокирует следующие команды lane. Полноценный dead-letter UI и retention failed-команд не входят в этот срез.

## Startup replay

После первого кадра приложения выполняется однократный foreground replay для текущего `ownerId`.

После хотя бы одной успешно восстановленной команды mobile перечитывает `GET /api/v1/home`. Outbox никогда не становится источником игрового состояния и не выполняет optimistic update.

Команды другого `ownerId` не отправляются. Полноценное переключение аккаунтов появится вместе с authentication.

## Последствия

Плюсы:

- один idempotency key переживает process restart;
- потерянный response не создаёт повторный debit/reward;
- activity и gameplay failures изолированы;
- решение не требует backend-контракта или новой серверной инфраструктуры;
- файловая модель легко покрывается unit tests.

Ограничения:

- replay работает только в foreground;
- нет автоматического таймера, reachability listener или background worker;
- нет offline read cache;
- удаление приложения удаляет outbox;
- storage не заменяет server-side persistent idempotency.

## Альтернативы

### Только in-memory key

Недостаточно: process restart теряет key.

### Shared preferences

Отклонено для critical command state: абстракция не даёт нужной модели атомарной замены, recovery и явной corruption policy.

### SQLite

На текущем объёме команд добавляет лишнюю зависимость, schema lifecycle и migration surface. Вернуться к SQLite можно, когда появятся большой offline backlog, сложные запросы или background worker.

### Немедленный background sync

Отложено до device/battery validation и появления понятного lifecycle/authentication.
