# Релизное досье `alpha-rc1`

[English original](alpha-rc1-release-dossier.md)

Это досье привязывает первый baseline программы валидации к одному неизменяемому
post-bootstrap commit ветки `master` и его интегрированным push-проверкам. Это
инженерная запись о кандидате, а не evidence production signing, устройств,
stage или stores.

## Запись решения

| Поле | Значение |
|---|---|
| Кандидат | `alpha-rc1` |
| Source commit | [`8d2b859b2f9b6a85530601eec45b3ccee612aaba`](https://github.com/MKSEgr/walking-rpg/commit/8d2b859b2f9b6a85530601eec45b3ccee612aaba) |
| Git tree | `979e7299f62be8cdb4af1e62b5b80f4615043acc` |
| Source timestamp | `2026-08-07T13:05:09Z` |
| Evidence проверено | `2026-08-07` |
| Автор evidence | Выполнение Codex для [TASK-001 / issue #147](https://github.com/MKSEgr/walking-rpg/issues/147) |
| Полномочия на решение | Maintainer репозитория, принявший TASK-001 ручным merge |

`alpha-rc1` означает ровно указанные выше commit и tree. Запись решения вступает
в силу после merge PR для TASK-001; до этого issue #147 остаётся открытым. Метку
нельзя незаметно переносить на другой SHA. Для successor source commit требуется
новое решение о кандидате и полное досье, собранное из интегрированных проверок
этого commit.

Выбранный commit — squash merge
[`[TASK-000] Bootstrap the validation programme`](https://github.com/MKSEgr/walking-rpg/pull/163).
Это первое состояние `master` после W0.1; прежние issues автономного scope
[#26](https://github.com/MKSEgr/walking-rpg/issues/26) и
[#29](https://github.com/MKSEgr/walking-rpg/issues/29) закрыты.

## Интегрированные push gates

Оба обязательных workflow запущены одним и тем же `push` в `master`; каждый
сообщает точный source commit выше и успешно завершён.

| Gate | Run | Начало | Завершение | Результат |
|---|---|---|---|---|
| Standard CI | [`CI #580` / run `31181017936`](https://github.com/MKSEgr/walking-rpg/actions/runs/31181017936) | `2026-08-07T13:05:13Z` | `2026-08-07T13:10:22Z` | `success` |
| Release packaging and policy | [`Release quality #461` / run `31181017679`](https://github.com/MKSEgr/walking-rpg/actions/runs/31181017679) | `2026-08-07T13:05:13Z` | `2026-08-07T13:14:01Z` | `success` |

Успешные jobs Standard CI:

- структура репозитория;
- backend Java 21: compile, test compile, unit/API и PostgreSQL
  integration/migration tests;
- Flutter 3.44.7: format, analyze и tests;
- Android host debug APK;
- iOS host simulator debug build.

Успешные jobs Release quality:

- release policy и deterministic metadata;
- исполняемый backend package;
- очищенная synthetic PostgreSQL backup/restore drill;
- Android unsigned AAB;
- iOS no-codesign application archive.

## Сохранённые artifacts и digests

Все artifacts ниже относятся к Release quality run `31181017679`, сообщают
`head_sha=8d2b859b2f9b6a85530601eec45b3ccee612aaba` и хранились GitHub Actions
14 дней. Artifact digest — сообщённый GitHub SHA-256 скачанного ZIP artifact;
payload digest прочитан из сохранённого checksum-файла и независимо пересчитан
после скачивания.

| Artifact | ID | GitHub artifact SHA-256 | Payload и проверенный SHA-256 |
|---|---:|---|---|
| `release-build-metadata` | `8994762914` | `f7751f8d844ffee32a5bb7e59d349b5274f5ed15cd3e7edf687c5544fa7dd797` | `build-metadata.json`: `2fce13c5dc2292da73ff2b3e8445a7e3361e616d2ed0a024be04a9fb527b3589` |
| `backend-release-candidate` | `8994764977` | `e5e20b34de151cd4935c0de10eb13e19e7ebf3d630438c64c8f465e29ddab2e4` | `walking-rpg-backend-0.1.0-SNAPSHOT.jar`: `ae43eff739e3527c4b625f466886208c96c0793b0923c5a2d3757f145b83a4d1` |
| `synthetic-backup-restore-evidence` | `8994781320` | `f221257f115c2db2e05df1aedde749271cd6968b9542b505f6d7a22a99da9fa4` | `evidence.json`: `ba67ad54c158c5af2c229bb1b1c74c136e727d9e3d25fac27f05e9edbab7fc54` |
| `android-unsigned-release-aab` | `8995010209` | `dc41c081573b4cfb0a35b654f63a36c547f9cb9b2979a6aa81f25e420c13e1e2` | `app-release.aab`: `c9b75c62bd2f90720dfba9ed7a3f7a0c9a529abff23c68b97dbc8c66a565a02b` |
| `ios-no-codesign-release-app` | `8994878378` | `3ea353140910a822f1786e118c62ef58998b0b1b593093af8c1d6a3f5db7ed15` | `WalkingRPG-no-codesign.zip`: `84753b025f3fe9bf805f20eeaab509b9c23f8a3640e297e1d649bfa81a5027dc` |

Успешный CI run не сохранил diagnostic artifacts, потому что его upload steps
выполняются только при ошибке.

### Build metadata

Сохранённые metadata schema-v2 были независимо сгенерированы повторно из
зафиксированного checkout и совпали побайтно.

| Поле | Значение |
|---|---|
| Application | `0.1.0+1` |
| Source commit / tree | `8d2b859b2f9b6a85530601eec45b3ccee612aaba` / `979e7299f62be8cdb4af1e62b5b80f4615043acc` |
| Flutter / Java | `3.44.7` / `21` |
| Последняя версия Flyway | `17` |
| Активная версия content | `chapter-1-v1` |
| Android | `com.walkingrpg.walking_rpg_mobile`; compile/target/min SDK `36/36/26` |
| iOS | `com.walkingrpg.walkingRpgMobile`; deployment target `14.0` |
| Декларация signing | Android и iOS: `external-protected-environment` |

### Synthetic restore evidence

Сохранённая restore receipt явно имеет
`scope=SYNTHETIC_CI`, `productionValidated=false` и
`actualProductionDrillRequired=true`. Она фиксирует PostgreSQL `17.10`, Flyway
version `17`, покрытие fixtures всех 33 application tables и точное совпадение
source/restored manifests:

- schema: `26b728b6d926e18fcc04ccba90dfc21838a721c976ac025326af67a8d5b2c411`;
- data: `2fe09f8796ae05c737250b282e612cec76ccf88d39e8ba1cdce4840a53c751fd`;
- sequences: `e0ca1b16b11db35b90e3eccba877939e6d59efa4f489b759098410001a3f2110`.

Synthetic database dump намеренно не сохранялся. Эта receipt не закрывает gate
реального восстановления из backup.

## Выполненная проверка

- точный SHA `master` был независимо определён через GitHub и
  `git ls-remote`;
- Git tree получен из зафиксированного commit и совпал с сохранёнными build
  metadata;
- conclusions обоих push workflows и каждого job проверены на точном SHA;
- все пять release artifacts скачаны через GitHub, а SHA-256 их ZIP совпали с
  provenance GitHub;
- все сохранённые payload checksum-файлы совпали с независимо рассчитанными
  SHA-256;
- build metadata повторно созданы командой
  `scripts/generate-build-metadata.sh` из зафиксированного checkout и сравнены
  побайтно;
- проверены checksum synthetic restore receipt и её явно непродукционный scope.

Это досье не содержит credentials, signing material, tokens, необработанные
health/identity data или PII.

## Feature freeze после baseline

`alpha-rc1` неизменяем. Работа после этого baseline ограничена:

1. release blockers, затрагивающими безопасность, экономику, целостность данных,
   обязательные launch flows или rollback;
2. исправлениями для физических устройств с воспроизводимым redacted evidence;
3. production wiring/configuration, необходимыми для gates E2, E3 и E7, с
   сохранением fail-closed defaults;
4. evidence-driven fixes со связанным defect, затронутым сценарием и rerun.

Расширение gameplay, широкие изменения дизайна и speculative platform work
остаются за пределами freeze. Любое разрешённое изменение source создаёт
successor candidate; оно не изменяет `alpha-rc1` и не переносит его метку.

## Внешние blockers и отсутствующие claims

Это досье доказывает только воспроизводимый code-complete engineering baseline.
Оно **не** утверждает, что:

- Android или iOS artifacts подписаны для production или являются
  устанавливаемыми distribution candidates;
- сценарии HealthKit/Health Connect или account lifecycle пройдены на физических
  устройствах;
- существуют production-like stage, реальный OIDC provider, TLS database,
  monitoring или реальное восстановление из backup;
- готовы developer accounts, public URLs, store declarations, submission или
  review gates;
- прошли validation product value, usability, retention или closed-beta
  thresholds.

Эти gates остаются закреплены за связанными задачами в
[`VALIDATION_BACKLOG.md`](../VALIDATION_BACKLOG.md).

## Stop и rollback

До merge закрытие PR для TASK-001 оставляет решение `alpha-rc1` не вступившим в
силу. После merge любое расхождение provenance или признание integrated gate
недействительным должно создать release-blocker issue и пометить это досье
отозванным в новом PR. Нельзя редактировать эту запись так, чтобы `alpha-rc1`
указывал на другой SHA; вместо этого нужно создать и проверить successor
candidate.

## Acceptance evidence

- [x] Один точный SHA/tree является единственным baseline `alpha-rc1`.
- [x] Push runs Standard CI и Release quality зелёные на том же SHA.
- [x] Имена artifacts, ID, доступные digests и build metadata записаны без
  secrets.
- [x] Release documentation и changelog ссылаются на это досье.
- [x] Изменения TASK-001 ограничены release/evidence documentation.
