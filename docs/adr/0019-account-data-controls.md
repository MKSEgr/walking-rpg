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
  системное приложение.
- Удаление выполняется через
  `POST /api/v1/account/deletion-requests` с обязательными
  `Idempotency-Key` и точным server-side подтверждением `DELETE`.
- Перед destructive request mobile показывает два независимых подтверждения,
  запускает OIDC authorization с `prompt=login` и принимает только ту же
  canonical owner identity.
- Backend удаляет данные транзакционно и возвращает постоянную UUID-квитанцию.
  Повторный запрос возвращает ту же квитанцию.
- Квитанция хранит SHA-256 subject и request key, timestamps и receipt UUID.
  Raw OIDC subject и экспортированные данные в ней не сохраняются.
- Subject-level advisory lock сериализует удаление и новые записи. После
  удаления account registry возвращает `410 ACCOUNT_DELETED` для обычных
  authenticated операций; только deletion endpoint допускает replay квитанции.
- Mobile Bearer transport не пытается refresh при `410 ACCOUNT_DELETED` и
  принудительно запускает тот же fail-closed logout/cleanup, закрывая окно
  process death между server receipt и локальной очисткой.
- После подтверждённого backend deletion mobile немедленно выполняет обычный
  fail-closed logout: останавливает runtime, очищает owner cache/outbox и secure
  tokens, затем пытается завершить IdP session.

## Consequences

- Потеря сетевого ответа не заставляет пользователя угадывать, завершилось ли
  удаление.
- Старый access token не может заново создать `app_user` или связанные данные.
- Ошибка до backend receipt не очищает локальную сессию и допускает безопасный
  retry с тем же key.
- Production identity-provider account deletion не имитируется. Его поддержка
  или документированное отсутствие собственной IdP-учётной записи остаётся
  внешним launch decision.
- Retention и законное основание хранения минимальной deletion receipt должны
  быть закреплены в production privacy/retention policy.
