# 0034 — решения по продукту и выпуску alpha

- Статус: Accepted with blockers
- Дата решения: 2026-08-08
- Decision authority: Product Owner [@MKSEgr](https://github.com/MKSEgr)
- Связанная задача: [TASK-002 / issue #148](https://github.com/MKSEgr/walking-rpg/issues/148)
- Подтверждение владельца: [issue comment от 2026-08-08](https://github.com/MKSEgr/walking-rpg/issues/148#issuecomment-5226010194)
- Release baseline: [`alpha-rc1`](../evidence/alpha-rc1-release-dossier.ru.md)
- Validation programme: [`VALIDATION_BACKLOG.md`](../VALIDATION_BACKLOG.md)

## Контекст

До начала physical-device, stage, IdP и store gates проекту требуется единая
запись решений владельца продукта. Эта ADR фиксирует только решения и
ответственных. Она не является доказательством готовности инфраструктуры,
реальных токенов, developer accounts, public URLs, устройств, store submission
или продуктовых метрик.

Секреты, verification documents, signing material, налоговые идентификаторы и
другие персональные реквизиты в репозитории не хранятся.

## Принятые решения

| Область | Решение | Owner | Дата |
|---|---|---|---|
| Название | Рабочее международное название — **Step Beyond**, русское название — **«Шаг за пределы»**. Название остаётся рабочим до отдельной проверки бренда и store records. | Product Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Главная эмоция | **Предвкушение открытия**: «ещё один шаг — и экспедиция откроет что-то новое». | Product Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| География alpha/beta | Internal alpha и первая closed beta проводятся в России. | Product/Cohort Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Языки alpha/beta | Русский и английский. При регистрации пользователь должен явно выбрать язык; для тестирования в России русский предлагается первым. Реализация и device evidence относятся к [issue #170](https://github.com/MKSEgr/walking-rpg/issues/170). | Product Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Production IdP | Auth0 B2C с EU tenant; production profile остаётся fail-closed до проверки реальных issuer/audience/client/redirect/scopes/claims и токенов в TASK-005. | Configuration Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Apple account | Apple Developer Program — `Individual`; Account Holder — [@MKSEgr](https://github.com/MKSEgr). Реальный status/verification проверяется в TASK-007. | [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Google account | Google Play Console — `Personal`; account owner — [@MKSEgr](https://github.com/MKSEgr). Реальный status и применимый testing gate проверяются в TASK-007. | [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Юридический оператор | Индивидуальный предприниматель Егоров Максим Сергеевич. Налоговые идентификаторы и verification records остаются вне Git. | Legal/Product Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Push | `disabled` для internal alpha, closed beta и первой публичной версии. Включение требует отдельного датированного go/no-go. | Product Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Платежи | `disabled` для internal alpha, closed beta и первой публичной версии. Включение требует отдельного датированного go/no-go. | Product Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Device validation | Ответственный за реальные устройства, redacted evidence и rerun — [@MKSEgr](https://github.com/MKSEgr). | Device-validation Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Cohort | Набор, волны и stop communication — [@MKSEgr](https://github.com/MKSEgr). | Cohort Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Support | Alpha support и incident intake — [@MKSEgr](https://github.com/MKSEgr); целевой канал — `support@walkingrpg.app` после публикации домена. | Support Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |
| Stop authority | Release Owner [@MKSEgr](https://github.com/MKSEgr) вправе немедленно остановить rollout. Возобновление требует defect issue, исправления, повторного прогона затронутого сценария и явного решения Product Owner. | Release Owner [@MKSEgr](https://github.com/MKSEgr) | 2026-08-08 |

## Явные blockers

### Stage и hosting

- Статус решения: `ACCEPTED_FOR_IMPLEMENTATION`; реальное окружение остаётся
  `EXTERNAL_VALIDATION_REQUIRED`.
- Stage name: `walking-rpg-alpha-eu`.
- Provider/region: DigitalOcean App Platform и Managed PostgreSQL 17 Standard,
  Frankfurt (`fra`).
- Contour: один backend instance 1 GiB и один PostgreSQL node без standby;
  бюджетный gate — до `$30/month` без Auth0, домена, налогов и внешнего log
  sink.
- Hosting Owner: [@MKSEgr](https://github.com/MKSEgr).
- Release Owner: [@MKSEgr](https://github.com/MKSEgr).
- Stop authority: Release Owner.
- Полный обратимый контракт, риски и внешние gates зафиксированы в
  [ADR 0036](0036-digitalocean-alpha-stage.md).
- Следующее действие: merge repository contract, затем owner-approved paid
  deployment и redacted evidence по TASK-006. До этого stage не считается
  существующим или validated.
- Дата изменения решения: 2026-08-09.

### Домен и public URLs

- Статус: `BLOCKED` — `walkingrpg.app` не зарегистрирован, страницы не
  опубликованы.
- Целевой домен: `walkingrpg.app`, при условии доступности и регистрации.
- Целевые URL:
  - `https://walkingrpg.app/privacy`;
  - `https://walkingrpg.app/support`;
  - `https://walkingrpg.app/delete-account`.
- Следующее действие: [@MKSEgr](https://github.com/MKSEgr) регистрирует домен и
  публикует русскую и английскую версии Privacy, support и account-deletion
  страниц; фактическая доступность и ownership проверяются в TASK-007.
- Целевая дата: 2026-08-22.
- Дата фиксации blocker-а: 2026-08-08.

Целевые адреса не являются утверждением, что домен или страницы уже существуют.

## Начальные thresholds

Порог расширения internal alpha:

- не менее 12 участников, минимум по 4 реальных пользователя на iOS и Android;
- не менее `9/12` завершают первые 10 минут без вмешательства разработчика;
- более `70%` завершивших onboarding разрешают чтение шагов;
- более `55%` получают первую награду в первые сутки;
- crash-free sessions `>99,5%`;
- sync error `<1%`;
- instrumentation coverage обязательных milestones `>=95%`;
- отсутствуют release blockers.

Порог расширения closed beta:

- D7 `>25%`;
- D30 `>10%`;
- Meaningful Active Week `>=20%` eligible cohort;
- сохраняются alpha-пороги стабильности;
- продуктовые выводы принимаются только при instrumentation coverage `>=95%`.

Это стартовые decision thresholds, а не подтверждённые продуктовые результаты.
Их фактическая проверка относится к TASK-012, TASK-016 и TASK-017.

## Stop и rerun

Немедленный `STOP` обязателен при:

- owner-isolation или authentication bypass;
- утечке identity/health data;
- двойном начислении, повреждении экономики или потере данных;
- неработающем обязательном удалении аккаунта;
- раскрытии credentials или signing material;
- невозможности rollback/restore во время инцидента.

`FIX_AND_RERUN` применяется при непройденном продуктовом threshold либо
воспроизводимом дефекте mandatory flow. Возобновление rollout допускается только
после defect issue, исправления и повторного evidence затронутого сценария.

## Feature freeze

[`alpha-rc1`](../evidence/alpha-rc1-release-dossier.ru.md) неизменяем. После
baseline разрешены только:

1. release blockers по безопасности, экономике, целостности данных,
   обязательным launch flows и rollback;
2. исправления по результатам physical-device проверки с воспроизводимым
   redacted evidence;
3. production wiring/configuration для E2, E3 и E7 с сохранением fail-closed
   defaults;
4. evidence-driven fixes со связанным defect issue и повторным прогоном.

В рамках уже согласованного alpha-набора допускается завершение Искры, Мха,
Навигатора и утверждённых пилотов только когда изменение необходимо для
обязательного alpha flow или device validation. Новые питомцы, пилоты, маршруты,
механики и широкая переработка дизайна заморожены.

Любое разрешённое изменение исходного кода создаёт новый release candidate и
не переносит метку `alpha-rc1` на другой SHA.

## Последствия и пересмотр

- Выбор языка при регистрации является обязательным требованием из
  [issue #170](https://github.com/MKSEgr/walking-rpg/issues/170), но эта ADR не
  заявляет его реализацию или validation.
- Auth0, account types и public URLs остаются решениями/целями до реального
  redacted evidence соответствующих задач.
- Stage-dependent задачи используют DigitalOcean contract из ADR 0036, но не
  заявляют deployment или validation без внешнего evidence.
- Обратимые решения пересматриваются отдельным PR с причиной, owner и датой.
- `CODE_COMPLETE` не означает `VALIDATED`.
