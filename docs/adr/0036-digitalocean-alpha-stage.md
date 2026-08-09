# 0036 — DigitalOcean production-like stage для internal alpha

- Статус: Accepted for implementation; external validation required
- Дата решения: 2026-08-09
- Decision authority: Product Owner [@MKSEgr](https://github.com/MKSEgr)
- Связанная задача: [TASK-006 / issue #151](https://github.com/MKSEgr/walking-rpg/issues/151)
- Stage name: `walking-rpg-alpha-eu`
- Hosting/Release Owner: [@MKSEgr](https://github.com/MKSEgr)

## Контекст

Internal alpha рассчитана на 12 участников и один backend. AWS ECS/Fargate с
RDS даёт нужные primitives, но создаёт несоразмерные этому этапу стоимость и
операционную поверхность. Render дешевле в минимальной конфигурации, однако на
момент выбора его documented internal-database contract не давал достаточного
доказательства exact `sslmode=verify-full` для текущего fail-closed guard.

DigitalOcean Managed PostgreSQL Standard с июля 2026 года документирует
`verify-full`, downloadable CA и hostname verification. App Platform
поддерживает Frankfurt, отдельные readiness/liveness checks, encrypted runtime
variables, database bindables, deployment rollback и built-in alerts. Это
закрывает программный deployment contract без перехода к микросервисам.

Решение предварительно принято владельцем для подготовки stage. Оно не
разрешает создание платных ресурсов и не утверждает, что окружение уже
развёрнуто или проверено.

## Решение

Для internal alpha используется следующий обратимый контур:

| Область | Решение |
|---|---|
| Provider | DigitalOcean |
| Region | App Platform `fra` / Frankfurt |
| Stage | `walking-rpg-alpha-eu` |
| Backend | один App Platform service, `apps-s-1vcpu-1gb`, один instance |
| Database | Managed PostgreSQL 17 Standard, один node, без standby |
| Source | `MKSEgr/walking-rpg`, manual deployment, autodeploy disabled |
| Owners | Hosting Owner и Release Owner — `@MKSEgr` |
| Stop authority | Release Owner |
| Budget gate | до `$30/month` без Auth0, домена, налогов и внешнего log sink |

Один instance выбран сознательно: встроенный in-process global limiter остаётся
глобальным для этого контура. Перед масштабированием выше одного instance
требуется отдельный distributed rate-limit decision.

### Database trust boundary

- Используется только custom database/user, а не `defaultdb`/`doadmin`.
- App Platform получает host, port, database, user, password и CA через
  database bindable variables. Literal credentials и connection strings в Git
  запрещены.
- Protected profile собирает ровно один canonical JDBC URL:
  `jdbc:postgresql://<dns-host>:<port>/<db>?sslmode=verify-full`.
- Container entrypoint записывает CA в `${HOME}/.postgresql/root.crt` с mode
  `0600`, удаляет CA из JVM environment и запускается непривилегированным UID.
- App добавляется в managed database Trusted Sources. Любой дополнительный
  source требует отдельной датированной причины и удаления после drill.
- Database user не получает superuser, role creation, database creation или
  replication privileges. Для alpha тот же ограниченный schema owner выполняет
  Flyway и runtime DML; разделение migrator/runtime roles пересматривается перед
  public beta либо раньше при появлении второго сервиса.

### Application and ingress boundary

- `stage` profile, JWT mode, Auth0 audience и namespaced claims обязательны;
  sandbox payment и development push остаются disabled.
- `/readyz` проверяет PostgreSQL и управляет включением instance в трафик.
- `/livez` не зависит от PostgreSQL и управляет restart.
- Actuator/Prometheus остаются на `127.0.0.1:8081` и не публикуются через
  App Platform ingress.
- Edge cache отключён. Enhanced Threat Control включён и должен пройти
  physical mobile smoke test; неожиданные `403` являются stop condition.
- Graceful shutdown получает 30 seconds drain до `TERM` и 30 seconds после
  `TERM`, что превышает внутренний 20-second Spring shutdown budget.
- CPU, memory, restart и deployment alerts объявлены в App Spec. Notification
  destination и фактическая доставка проверяются с owner account.

### Release and rollback boundary

`deploy_on_push` выключен. Каждый deployment record обязан содержать App
Platform deployment ID, exact `source_commit_hash`, source tree, UTC interval,
public endpoint и предыдущий safe deployment ID. Последний Git branch head сам
по себе не является deployment evidence.

App rollback возвращает только ранее сохранённый deployment/config. Flyway
migrations считаются forward-compatible; destructive schema rollback запрещён.
PITR/restore — отдельный data recovery procedure, а не способ обычного code
rollback.

## Репозиторный контракт

- [`infra/digitalocean/app.yaml.template`](../../infra/digitalocean/app.yaml.template)
  — reviewed App Spec без внешних значений и секретов.
- [`render_digitalocean_stage_spec.py`](../../scripts/operations/render_digitalocean_stage_spec.py)
  — fail-closed renderer Auth0/database identifiers.
- [`backend/Dockerfile`](../../backend/Dockerfile) и
  [`backend/docker-entrypoint.sh`](../../backend/docker-entrypoint.sh) — Java 21
  image, non-root runtime и pgJDBC CA delivery.
- [`DIGITALOCEAN_STAGE_RUNBOOK.md`](../DIGITALOCEAN_STAGE_RUNBOOK.md) — owner
  deployment, verification, stop и rollback procedure.

Этот контракт имеет статус `CODE_COMPLETE` только после merge и green CI.
TASK-006 остаётся `EXTERNAL_VALIDATION_REQUIRED`, пока нет реального deployment
evidence.

## Явные внешние blockers

- DigitalOcean account/project, billing approval и managed PostgreSQL cluster;
- реальный Auth0 EU tenant/application/API/Action и значения issuer/JWKS/audience;
- runtime log forwarding с принятым сроком хранения;
- alert notification destination;
- фактические TLS, Trusted Sources, least-privilege, probe, log, alert, PITR и
  rollback checks;
- новый exact release candidate после merged PR #165–#173 и этого изменения.

## Принятые риски alpha

- один database node без automatic standby; краткая недоступность допустима при
  немедленной остановке cohort;
- один backend instance; horizontal availability и distributed limiter
  отложены;
- provider URL используется до регистрации custom domain;
- runtime logs не считаются retained evidence без отдельного supported log
  destination.

HA/standby обязателен к повторному рассмотрению перед публичным запуском, при
строгом RTO либо если downtime мешает alpha protocol. AWS/другой контур
пересматривается при несовместимости App Platform с protected startup,
непредсказуемых mobile `403`, превышении бюджета или невозможности доказать
restore/rollback.

## Источники provider contract

- [DigitalOcean App Spec](https://docs.digitalocean.com/products/app-platform/reference/app-spec/)
- [App Platform bindable variables](https://docs.digitalocean.com/products/app-platform/how-to/use-environment-variables/)
- [PostgreSQL `verify-full`](https://docs.digitalocean.com/products/databases/postgresql/how-to/connect/)
- [PostgreSQL trusted sources and VPC guidance](https://docs.digitalocean.com/products/databases/postgresql/concepts/best-practices/)
- [App Platform alerts](https://docs.digitalocean.com/products/app-platform/how-to/create-alerts/)
- [App Platform logs](https://docs.digitalocean.com/products/app-platform/how-to/view-logs/)
