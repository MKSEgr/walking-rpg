# Release checklist

CI создаёт технические release candidates. Подпись и публикация выполняются только во внешней защищённой среде.

## Current engineering baseline

`alpha-rc1` зафиксирован в
[release dossier](evidence/alpha-rc1-release-dossier.md) на одном exact
post-bootstrap `master` SHA/tree с зелёными integrated push checks и
проверенными unsigned/no-codesign artifact digests. Dossier не заменяет
production signing, physical-device, stage, real-restore или store evidence.

## Source gate

- [ ] PR основан на актуальном `master`.
- [ ] Standard CI и `Release quality` зелёные.
- [ ] CODEOWNER одобрил последний push.
- [ ] Review threads закрыты.
- [ ] В diff нет export/apply/overlay-файлов.
- [ ] Flyway-цепочка непрерывна, upgrade tests зелёные.

## Artifact gate

- [ ] Backend image опубликован protected manual workflow из approved
      `master` SHA/tree; GHCR digest и receipt artifact checksum проверены.
- [ ] Stage App Spec содержит этот immutable digest, не Git branch/image tag;
      embedded source SHA/tree совпадают с approved runtime values.
- [ ] Проверены metadata и SHA-256.
- [ ] Проверены backend JAR и SHA-256.
- [ ] Проверены Android unsigned AAB и SHA-256.
- [ ] Build metadata и Gradle verification подтверждают `compileSdk = 36`,
      `targetSdk = 36` и `minSdk = 26`; manifest финального AAB отдельно
      проверен через `bundletool`.
- [ ] Проверены iOS no-codesign archive и SHA-256.
- [ ] Metadata, backend, Android и iOS candidates собраны из одного exact
      source SHA и tree; version/build/commit/tree согласованы внутри одного
      workflow run.

## Identity gate

- [ ] Backend production profile запущен в `jwt` mode; demo/dev headers не принимаются.
- [ ] OIDC issuer, JWKS и audience соответствуют production client.
- [ ] User/admin claims проверены на реальных токенах.
- [ ] Access token после `prompt=login` + `max_age=0` содержит подписанный
      `auth_time`; stale/missing claim отклоняется deletion endpoint.
- [ ] Mobile Authorization Code + PKCE, refresh, expiry и logout пройдены end-to-end.
- [ ] Logout/account switch очищает локальную session, read cache и command outbox по согласованной политике.
- [ ] Telegram connection использует back-channel OIDC, PKCE S256 и scopes
      ровно `openid profile`; `phone` и `telegram:bot_access` не запрошены.
- [ ] Telegram включён только для нужного Native Application, не promoted to
      domain level; RU/EN login/cancel/reauth проверены на физических iOS и
      Android без токенов или PII в evidence.

## Environment и provider gate

- [ ] `stage-release` требует approval Release Owner; backend GHCR package
      доступен App Platform без credential literal в App Spec.
- [ ] Backend запущен ровно с одним защищённым профилем `stage` или `prod`;
      `local`/`test` не активны.
- [ ] Datasource URL, username и password переданы защищённой средой; JDBC URL
      использует канонический DNS host и `sslmode=verify-full`, а DNS/TLS
      соединение с реальной БД подтверждено.
- [ ] Provider CA получен только из защищённого runtime binding, установлен с
      mode `0600` и не попал в logs/evidence; Trusted Sources ограничены
      reviewed application.
- [ ] `walking-rpg.providers.payment=disabled` и
      `walking-rpg.providers.push=disabled`; попытки отклоняются до новой state
      mutation.
- [ ] Production-like platform snapshot возвращает effective
      `sandboxPaymentsEnabled=false`; release mobile не показывает purchase UI
      ни для него, ни для cached snapshot.
- [ ] `backgroundHealthSyncEnabled=false`; foreground/resume fallback не
      описан как гарантированная background delivery.
- [ ] Если production billing или push ещё не подключены, соответствующие
      функции и store promises остаются выключены.

## Protected signing environment

- [ ] Финальные Android application ID и iOS Bundle ID согласованы с
      store records и production OIDC redirects.
- [ ] Android external signing properties и upload keystore находятся вне
      source tree; release не использует debug key.
- [ ] Android AAB подписан production upload key, signature/fingerprint и
      SHA-256 проверены.
- [ ] iOS archive подписан Distribution identity/profile; entitlements,
      embedded profile и SHA-256 проверены.
- [ ] Секреты доступны только protected environment и удалены из временного
      runner storage после build.
- [ ] Signed artifacts собраны из текущего post-merge `master` SHA, для
      которого Standard CI и Release quality push checks зелёные.
- [ ] `master` tree SHA совпадает с head tree CODEOWNER-approved PR; номер PR,
      оба tree SHA и отдельный owner signing approval сохранены в evidence.
- [ ] Публикация требует отдельного ручного approval владельца.

Порядок и допустимое evidence:
[PROTECTED_MOBILE_SIGNING.md](PROTECTED_MOBILE_SIGNING.md).

## Store и privacy

- [ ] Privacy policy опубликована по постоянному URL.
- [ ] Health declaration соответствует только `STEPS READ`.
- [ ] App Privacy/Data Safety заполнены по `STORE_DECLARATIONS.md`.
- [ ] JSON-экспорт проверен на production-like аккаунте: файл открывается,
      содержит только данные текущего subject и не содержит push token.
- [ ] Удаление проверено end-to-end: fresh login той же identity, два
      подтверждения, повтор запроса с той же квитанцией, `410` для stale token
      и очистка local session/cache/outbox.
- [ ] Зафиксировано, удаляется ли внешняя IdP-учётная запись; опубликован
      обязательный web deletion URL для Google Play.
- [ ] Sandbox payment не описан как production billing.

## Device и rollout

- [ ] Выполнен `DEVICE_VALIDATION_PROTOCOL.md`.
- [ ] Есть evidence для поддерживаемых iOS/Android сценариев.
- [ ] Измерена батарея.
- [ ] Определены beta cohort, stop conditions и rollback plan.
- [ ] Compass funnel snapshot привязан к exact build/cohort/периоду;
      `instrumentationRate`, out-of-order и target-without-start проверены до
      выводов о craft/equip/route conversion.
- [ ] Durable result activation выполняется только после drain старых backend
      instances; rollback проверяет disabled gate и ноль pending receipts.
- [ ] V14 оставила `chapter-1-v1` активной; `chapter-1-v2` опубликована только
      после полного drain старого backend pool и проверки нулевых route rows.
- [ ] Перед V15 проверена строка `chapter-1-v2`: для уже публиковавшейся v2
      первая активация явно восстановлена из immutable rollout/audit evidence,
      а не из mutable `created_at`; без evidence migration должна остановиться.
- [ ] V15 заполнит `activated_at` только при первой активации; повторная
      публикация той же версии сохраняет timestamp и compass route baseline.

## Operations

- [ ] A4b ingress/probe/metrics/timeout tests и release-policy checks зелёные.
- [ ] Synthetic backup/restore evidence имеет
      `scope=SYNTHETIC_CI`, `productionValidated=false`, корректные checksums и
      exact schema/data/sequence match.
- [ ] Liveness/readiness и защищённый metrics endpoint проверены в фактическом
      deployment; management listener не доступен из public ingress.
- [ ] Проверены внешние WAF/gateway/distributed abuse controls; per-process
      application limiter не выдан за глобальную quota.
- [ ] Настроены alerting, log retention и redaction без secrets/tokens.
- [ ] Назначены владельцы rollback и инцидента, procedure проверена.
- [ ] Backup создан фактическим production-процессом; restore drill выполнен в
      изолированной среде, проверены версия схемы и контрольные данные.
- [ ] Backup scheduling/encryption/retention, PITR и RPO/RTO policy утверждены
      и подтверждены датированным evidence.
- [ ] Production secrets rotation и least-privilege DB role подтверждены.
