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

## Protected signing environment

- [ ] Android AAB подписан production upload key вне source tree.
- [ ] iOS archive подписан Distribution identity/profile.
- [ ] Секреты доступны только protected environment.
- [ ] Публикация требует отдельного ручного approval владельца.

## Store и privacy

- [ ] Privacy policy опубликована по постоянному URL.
- [ ] Health declaration соответствует только `STEPS READ`.
- [ ] App Privacy/Data Safety заполнены по `STORE_DECLARATIONS.md`.
- [ ] Sandbox payment не описан как production billing.

## Device и rollout

- [ ] Выполнен `DEVICE_VALIDATION_PROTOCOL.md`.
- [ ] Есть evidence для поддерживаемых iOS/Android сценариев.
- [ ] Измерена батарея.
- [ ] Определены beta cohort, stop conditions и rollback plan.
