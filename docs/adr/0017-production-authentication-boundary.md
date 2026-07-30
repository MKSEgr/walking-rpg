# ADR 0017: production authentication boundary на OIDC/JWT

- Статус: accepted
- Дата: 2026-07-28

## Контекст

Первые вертикальные срезы использовали технические заголовки `X-User-Id`, `X-Device-Id`, `X-Mock-User` и `X-Mock-Authorities`. Это удобно локально, но не является границей доверия: сетевой клиент способен подставить чужой user/device/actor и попытаться обратиться к административным операциям.

До подключения store-клиента backend должен:

- принимать production identity только из проверенного access token;
- отделять обычные пользовательские операции от административных;
- не позволять контроллерам доверять identity из request body или произвольных headers;
- сохранять локальный режим разработки без ослабления production-конфигурации.

## Решение

### Режимы

`walking-rpg.security.mode` поддерживает два режима:

- `jwt` — production resource server;
- `dev-header` — явно включаемый локальный/test режим.

Базовая конфигурация использует `jwt` и отключает demo endpoint.
`application-local.yml` и test configuration включают `dev-header`;
`application-stage.yml` и `application-prod.yml` оставляют `jwt` и
`demo-endpoints-enabled=false`.

Одних YAML-значений недостаточно, потому что переменные окружения имеют более высокий приоритет. Поэтому `SecurityModeGuard` проверяет итоговую конфигурацию при старте приложения:

- `dev-header` и demo endpoint разрешены только с профилем `local` или `test`;
- защищённые `stage`/`prod` нельзя совмещать с `local`/`test`;
- профили `stage`/`prod` обязаны работать в `jwt` и без demo endpoint;
- device claim и user/admin authority mappings должны быть заданы и не должны совпадать.

Некорректная комбинация завершает startup до открытия HTTP-порта. Запуск без local/test profile не откатывается молча к небезопасным заголовкам даже при ошибочной переменной окружения.

Datasource и development-provider инварианты защищённых профилей собраны в
`ProductionRuntimeGuard`; тонкий `ProductionEnvironmentPostProcessor` запускает
datasource-часть до создания context/DataSource. Они расширяют runtime
boundary, но не меняют JWT-контракт этого ADR; см. ADR 0025.

### JWT validation

Spring Security Resource Server валидирует JWT по:

- подписи из `OIDC_JWK_SET_URI`;
- issuer из `OIDC_ISSUER_URI`;
- audience из `OIDC_AUDIENCE`;
- стандартным временным claims.

Обязательный `sub` становится каноническим `userId`. Человекочитаемый actor берётся из настраиваемого claim `preferred_username` и при отсутствии совпадает с `sub`.

### Authorities

Настраиваемые role/scope claims преобразуются в две прикладные authority:

- `ROLE_USER` — доступ к защищённым пользовательским `/api/v1/**`;
- `ROLE_ADMIN` — доступ к `/api/v1/admin/**`; admin также получает `ROLE_USER`.

Конвертер принимает только значения, явно указанные в `OIDC_USER_ROLE`, `OIDC_ADMIN_ROLE`, `OIDC_USER_SCOPE` и `OIDC_ADMIN_SCOPE`. Общие роли `USER`, `ADMIN`, `ROLE_USER` и `ROLE_ADMIN` сами по себе не считаются ролями Walking RPG: это предотвращает повышение привилегий из-за совпадения с посторонней ролью identity provider-а. При необходимости такое имя можно назначить явно в конфигурации.

Токен без прикладной user/admin authority может быть криптографически валиден, но получает `403` на прикладных endpoint-ах.

### Device identity

Activity sync не принимает произвольный `X-Device-Id` в JWT-режиме. Backend берёт подписанный claim `walking-rpg.security.device-claim` — по умолчанию `device_id` — и хранит только SHA-256 от `issuer + sub + claim name + claim value`.

Значение должно идентифицировать установку приложения или устройство и оставаться стабильным при обновлении access token и обычном повторном входе. Session claim `sid` не используется по умолчанию: он может меняться между сессиями и тем самым ломать device-scoped idempotency и high-watermark semantics.

Если стабильный claim отсутствует, activity sync завершается `401 AUTHENTICATION_ERROR`; остальные пользовательские операции могут выполняться без device identity. Если claim присутствует, но в JWT отсутствует `iss`, identity также отклоняется fail-closed.

Это промежуточная production-граница. Отдельная attestation/device-registration модель остаётся следующим anti-fraud усилением.

### Public surface

Без access token доступны только явно перечисленные операции:

- health probe;
- system info;
- content bootstrap;
- telemetry/crash ingestion, которым разрешён anonymous user;
- demo home только в local/test режиме.

Все остальные неизвестные маршруты запрещены fail-closed.

### Controller boundary

Контроллеры получают `RequestIdentity` из `SecurityContext`. Они не принимают user/device/actor headers и не доверяют identity из body. Audit actor административных изменений берётся из токена.

Identity provider принимает только ожидаемые principal-типы: проверенный `Jwt`/`JwtAuthenticationToken` либо локальный `WalkingRpgPrincipal`. Произвольный аутентифицированный principal не превращается автоматически в пользователя приложения.

Локальные headers обрабатываются только `DevHeaderAuthenticationFilter`, который не добавляется в JWT filter chain.

## Последствия

Плюсы:

- подмена `X-User-Id` в production не меняет subject;
- межпользовательская изоляция строится от подписанного `sub`;
- административные endpoint-ы имеют отдельную authority;
- protected `stage`/`prod` profiles не включают demo/dev identity;
- ошибочный runtime override небезопасного режима останавливает приложение;
- стабильная device identity не меняется вместе с OIDC-сессией;
- 401/403 имеют единый JSON-контракт `code/message/details/traceId`.

Ограничения текущего среза:

- mobile OIDC Authorization Code + PKCE, secure token storage, refresh и logout реализуются следующим PR;
- token revocation/introspection зависит от выбранного identity provider и его session policy;
- telemetry/crash ingestion остаётся anonymous, но получает bounded
  per-process rate/body boundary из [ADR 0026](0026-production-operational-controls.md);
  distributed ingress policy остаётся внешней;
- signed device claim и физическая attestation ещё не доказывают целостность устройства.

## Проверки

- unit tests role/scope converter-а, включая запрет неявных generic aliases;
- identity extraction из JWT и dev principal;
- отказ от session-only `sid`, missing issuer и неизвестного principal-типа;
- startup guard tests для профилей, demo/dev overrides и конфликтующих mappings;
- dev filter tests;
- filter-chain tests для anonymous/user/admin, 401/403 и игнорирования dev headers в JWT mode;
- controller tests, подтверждающие получение user/actor из security context;
- release-policy check запрещает identity headers вне dev filter и проверяет fail-closed profiles/guard.
