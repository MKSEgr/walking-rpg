# Release checklist

CI создаёт технические release candidates. Подпись и публикация выполняются только во внешней защищённой среде.

## Source gate

- [ ] PR основан на актуальном `master`.
- [ ] Standard CI и `Release quality` зелёные.
- [ ] CODEOWNER одобрил последний push.
- [ ] Review threads закрыты.
- [ ] В diff нет export/apply/overlay-файлов.
- [ ] Flyway-цепочка непрерывна, upgrade tests зелёные.

## Artifact gate

- [ ] Проверены metadata и SHA-256.
- [ ] Проверены backend JAR и SHA-256.
- [ ] Проверены Android unsigned AAB и SHA-256.
- [ ] Проверены iOS no-codesign archive и SHA-256.
- [ ] Version/build/commit совпадают с принятым PR.

## Identity gate

- [ ] Backend production profile запущен в `jwt` mode; demo/dev headers не принимаются.
- [ ] OIDC issuer, JWKS и audience соответствуют production client.
- [ ] User/admin claims проверены на реальных токенах.
- [ ] Access token после `prompt=login` + `max_age=0` содержит подписанный
      `auth_time`; stale/missing claim отклоняется deletion endpoint.
- [ ] Mobile Authorization Code + PKCE, refresh, expiry и logout пройдены end-to-end.
- [ ] Logout/account switch очищает локальную session, read cache и command outbox по согласованной политике.

## Environment и provider gate

- [ ] Backend запущен ровно с одним защищённым профилем `stage` или `prod`;
      `local`/`test` не активны.
- [ ] Datasource URL, username и password переданы защищённой средой; JDBC URL
      использует канонический DNS host и `sslmode=verify-full`, а DNS/TLS
      соединение с реальной БД подтверждено.
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

- [ ] Android AAB подписан production upload key вне source tree.
- [ ] iOS archive подписан Distribution identity/profile.
- [ ] Секреты доступны только protected environment.
- [ ] Публикация требует отдельного ручного approval владельца.

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
- [ ] Durable result activation выполняется только после drain старых backend
      instances; rollback проверяет disabled gate и ноль pending receipts.

## Operations

- [ ] Liveness/readiness и защищённый metrics endpoint проверены в фактическом
      deployment.
- [ ] Настроены alerting, log retention и redaction без secrets/tokens.
- [ ] Назначены владельцы rollback и инцидента, procedure проверена.
- [ ] Backup создан фактическим production-процессом; restore drill выполнен в
      изолированной среде, проверены версия схемы и контрольные данные.
- [ ] Production secrets rotation и least-privilege DB role подтверждены.
