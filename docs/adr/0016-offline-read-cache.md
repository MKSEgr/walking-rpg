# ADR 0016 — Read-only offline snapshot cache

## Статус

Accepted.

## Контекст

Durable mobile outbox уже сохраняет state-changing команды до подтверждённого ответа backend. Однако при временной недоступности сети пользователь видел только ошибку, даже если ранее приложение успешно получило `GET /api/v1/home` или `GET /api/v1/platform`.

Использовать outbox как read model нельзя: он хранит намерения пользователя, а не подтверждённое сервером состояние. Также нельзя разрешать новые игровые операции поверх устаревшего snapshot — это создаёт ложное представление о балансе ENERGY, progression и доступных наградах.

## Решение

Добавить отдельный versioned read cache для последних **валидированных server snapshots**:

```text
home     — ключ owner + localDate, TTL 36 часов
platform — ключ owner + current, TTL 7 дней
```

Хранилище находится в application-support directory и использует тот же crash-safe паттерн `target → .tmp → .bak`, что durable command store. При запуске выбирается самая новая валидная копия; повреждённые файлы помещаются в quarantine.

Fallback разрешён только для read-запросов при:

- transport/network error;
- HTTP `408`, `429`, `5xx`;
- некорректном успешном JSON/domain snapshot backend.

Fallback запрещён для `401`, `403`, validation/state conflicts и остальных terminal `4xx`.

Cached snapshot всегда повторно проходит domain decoding. UI явно показывает время snapshot и причину fallback. Все state-changing действия блокируются до получения свежего server state; ручной refresh остаётся доступен.

Перед отправкой state-changing команды зависимые snapshots инвалидируются: при transport error или malformed response результат команды может быть неоднозначным, поэтому старое состояние больше нельзя считать безопасным fallback. Если локальное хранилище не удалось инвалидировать, команда не отправляется и остаётся retryable в durable outbox. Успешная platform command сохраняет authoritative platform snapshot из response; home перечитывается отдельно для актуального ENERGY.

## Последствия

Положительные:

- пользователь может открыть последнее подтверждённое состояние при кратковременном outage;
- cached state не становится источником экономики или progression;
- terminal security/business errors не маскируются устаревшими данными;
- read cache и command outbox остаются независимыми механизмами.

Ограничения:

- cache не является полноценным offline gameplay;
- snapshot может быть устаревшим в пределах TTL и поэтому read-only;
- cache хранится локально под защитой sandbox/шифрования устройства, но не заменяет backend export/retention policy;
- background sync и conflict-free offline mutations этим решением не добавляются.
