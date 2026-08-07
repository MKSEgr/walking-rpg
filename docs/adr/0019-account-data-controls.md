# ADR 0019: Account data controls

- Status: Accepted
- Date: 2026-07-29

## Context

Backend уже умел выгружать и удалять данные пользователя, но mobile не давал
доступа к этим операциям. Удаление возвращало только boolean, поэтому клиент не
мог безопасно повторить запрос после потери ответа и показать подтверждаемую
квитанцию. Для store launch также нужен доступный внутри приложения flow
инициирования удаления.

## Decision

- `GET /api/v1/account/export` остаётся authenticated JSON export. Mobile
  создаёт временный файл для системного share sheet и удаляет staging-копию
  после его закрытия. Постоянное сохранение выполняет выбранное пользователем
  системное приложение. Все account-scoped секции backend читает из одного
  read-only `REPEATABLE_READ` snapshot, не смешивая конкурентные commits.
- Удаление выполняется через
  `POST /api/v1/account/deletion-requests` с обязательными
  `Idempotency-Key` и точным server-side подтверждением `DELETE`.
- Перед destructive request mobile показывает два независимых подтверждения,
  запускает OIDC authorization с `prompt=login`, `max_age=0` и принимает только
  ту же canonical owner identity.
- Backend независимо требует стандартный подписанный `auth_time` в access
  token. Допустимый возраст задаётся
  `ACCOUNT_DELETION_MAX_AUTH_AGE=PT5M`, а startup guard запрещает нулевое,
  отрицательное и превышающее 15 минут окно.
- OIDC NumericDate `auth_time` преобразуется в epoch nanoseconds без
  промежуточного `double` и сравнивается с age/skew boundary в исходной
  точности. Уже потерявшие исходную JSON decimal точность `Float`/`Double`,
  выходящие за `Instant` и sub-nanosecond значения отклоняются fail-closed
  вместо округления.
- Backend удаляет данные транзакционно и возвращает постоянную UUID-квитанцию.
  Повторный запрос возвращает ту же квитанцию.
- Account export берёт один connection и до начала database transaction
  захватывает на нём session-level subject lock, конфликтующий с deletion
  transaction lock. Затем тот же connection открывает read-only
  `REPEATABLE_READ`, проверяет deletion registry и формирует единый snapshot
  всех секций. Первый statement этой transaction возвращает PostgreSQL
  `statement_timestamp()` как `exportedAt` и одновременно фиксирует snapshot;
  JVM clock и задержка поздней секции не меняют observation boundary. Поэтому
  export либо сериализуется раньше deletion, либо после уже сохранённой
  квитанции получает `ACCOUNT_DELETED`. Session lock всегда снимается до
  возврата connection в pool; cleanup failure аварийно исключает connection,
  а `DB_POOL_SIZE=1` остаётся рабочей конфигурацией.
- Квитанция хранит SHA-256 subject и request key, timestamps и receipt UUID.
  Raw OIDC subject и экспортированные данные в ней не сохраняются.
- Subject-level advisory lock захватывается внутри той же database transaction
  до operation-specific locks, idempotency lookup и user-scoped mutation.
  Граница покрывает activity/platform/crafting/equipment, expedition
  advance/resolution и event-result acknowledgement; request security filter
  не заменяет эту транзакционную сериализацию. После удаления общий security
  filter до controller возвращает
  `410 ACCOUNT_DELETED` для всех authenticated операций, включая admin API;
  только deletion endpoint допускает replay квитанции.
- Mobile Bearer transport не пытается refresh при `410 ACCOUNT_DELETED` и
  принудительно запускает тот же fail-closed logout/cleanup, закрывая окно
  process death между server receipt и локальной очисткой.
- После подтверждённого backend deletion mobile немедленно выполняет обычный
  fail-closed logout: останавливает runtime, очищает owner cache/outbox и secure
  tokens, затем пытается завершить IdP session.

## Consequences

- Потеря сетевого ответа не заставляет пользователя угадывать, завершилось ли
  удаление.
- Украденного старого access token недостаточно для destructive request, даже
  если он ещё не истёк.
- Старый access token не может заново создать `app_user` или связанные данные.
- Ошибка до backend receipt не очищает локальную сессию и допускает безопасный
  retry с тем же key.
- Production identity-provider account deletion не имитируется. Его поддержка
  или документированное отсутствие собственной IdP-учётной записи остаётся
  внешним launch decision.
- Retention и законное основание хранения минимальной deletion receipt должны
  быть закреплены в production privacy/retention policy.
