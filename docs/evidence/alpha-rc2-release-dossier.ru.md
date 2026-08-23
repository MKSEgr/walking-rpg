# Release dossier `alpha-rc2`

[English version](alpha-rc2-release-dossier.md)

Этот dossier фиксирует post-roadmap baseline программы валидации: принятое
дерево исходников, его post-merge `master` anchor, точные автоматические
проверки и проверенные release artifacts. Это инженерный candidate record, а
не доказательство production signing, физических устройств, stage, магазинов
или продуктовой ценности.

## Decision record

| Поле | Значение |
|---|---|
| Candidate | `alpha-rc2` |
| Post-merge `master` anchor | [`70520cdc57bd0f1f8cafd7205ce1903afa19c5a9`](https://github.com/MKSEgr/walking-rpg/commit/70520cdc57bd0f1f8cafd7205ce1903afa19c5a9) |
| Source, создавший artifacts | [`3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23`](https://github.com/MKSEgr/walking-rpg/commit/3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23) |
| Exact content tree | `09a809cc126c24b8abf5214f60d527958bc71a03` |
| Принятое изменение | [PR #467](https://github.com/MKSEgr/walking-rpg/pull/467), forward delivery roadmap |
| Время source для artifacts | `2026-08-23T20:27:18Z` |
| Время merge anchor | `2026-08-23T20:44:56Z` |
| Evidence проверено | `2026-08-23` |
| Recorder | выполнение Codex по [F0 issue #468](https://github.com/MKSEgr/walking-rpg/issues/468) |
| Decision authority | maintainer репозитория, вручную принимающий issue #468 через merge |

PR #467 смержен squash-методом. Merge изменил identity коммита, но полностью
сохранил принятое дерево: PR source и защищённый post-merge `master` anchor
имеют exact tree `09a809cc126c24b8abf5214f60d527958bc71a03`. Release
artifacts записали PR source и это дерево; merge commit фиксирует принятие и
интеграцию того же содержимого.

`alpha-rc2` означает весь tuple выше, а не branch или перемещаемый label.
Решение вступает в силу после merge PR задачи #468. Запись нельзя менять так,
чтобы она указывала на другой source, anchor или tree. Для преемника нужен
новый candidate и отдельное evidence.

## Exact automated gates

Все проверки выполнены на source
`3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23` до принятия PR #467. Каждый job
завершился успешно.

| Gate | Run | Начало | Завершение | Результат |
|---|---|---|---|---|
| Standard CI | [CI #1083 / run `32664456691`](https://github.com/MKSEgr/walking-rpg/actions/runs/32664456691) | `2026-08-23T20:27:23Z` | `2026-08-23T20:31:51Z` | `success` |
| Release quality | [Release quality #964 / run `32664456649`](https://github.com/MKSEgr/walking-rpg/actions/runs/32664456649) | `2026-08-23T20:27:23Z` | `2026-08-23T20:35:34Z` | `success` |
| Release finalizer | [Finalizer #693 / run `32664456635`](https://github.com/MKSEgr/walking-rpg/actions/runs/32664456635) | `2026-08-23T20:27:23Z` | `2026-08-23T20:35:41Z` | `success` |

Standard CI проверил структуру/Auth0 contracts, Java 21 compile, unit/API,
PostgreSQL integration/migrations, Flutter format/analyze/tests, Android debug
host и iOS simulator host. Release quality проверил policy/metadata, backend
package и protected container, synthetic PostgreSQL restore, Android unsigned
AAB и iOS no-codesign archive.

## Retained artifacts и digests

Все artifacts принадлежат Release quality run `32664456649`, содержат
`head_sha=3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23` и истекают
`2026-09-06`. Archive digest — GitHub SHA-256 скачанного ZIP. В ходе #468
каждый ZIP скачан повторно: его SHA-256 совпал с GitHub, а payload checksum
независимо пересчитан.

| Artifact | ID | Archive SHA-256 | Payload и проверенный SHA-256 |
|---|---:|---|---|
| `release-build-metadata` | `9499622733` | `3d59024fbb629d6f1afef116da45ec5ba3b935007e4d616aed9702febbe7fdae` | `build-metadata.json`: `62467b575b336a5a7712d8fbadfeea10086cf911a1062fc4eb9b90270eaa46fe` |
| `backend-release-candidate` | `9499636180` | `731813a9a710ef1b38493ffbe702b464695874fa1f861560c7413f8d8ff72e7b` | `walking-rpg-backend-0.1.0-SNAPSHOT.jar`: `385478abf8949da2c2fcbe74066f3ccdb9952f90a017733d2ca47edec9085c65` |
| `synthetic-backup-restore-evidence` | `9499624257` | `32799d6e9b75e3818739f17e7b3511580d0d735f38bf2af54e160ebe9e181543` | `evidence.json`: `d8eaad08565d8516d7b47f7c5d961878ff5d8411af07b7d5a3f8658d1706789e` |
| `android-unsigned-release-aab` | `9499726494` | `05187e6a45b624785010bc6579f84deb86a5520efd4014eb525fbcae163d37da` | `app-release.aab`: `6d729dce28cf0926f391f01f5311b3154cab2987ec5ca8335e7872f21bacb356` |
| `ios-no-codesign-release-app` | `9499654080` | `02586b0927fb0952cdbcf35d923f84e31eb732a29a4a110db7a6a3ba9a619017` | `WalkingRPG-no-codesign.zip`: `32794aeda409c6b8b4863c1ab9372651b4707ac2c85f937bcff209dc7eca7ed7` |

## Build metadata

| Поле | Значение |
|---|---|
| Application | `0.1.0+1` |
| Source / tree | `3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23` / `09a809cc126c24b8abf5214f60d527958bc71a03` |
| Flutter / Java | `3.44.7` / `21.0.12+8.0.LTS` |
| Flyway latest version | `34` |
| Active content version | `chapter-1-v1` |
| Android | `com.walkingrpg.walking_rpg_mobile`; compile/target/min SDK `36/36/26` |
| iOS | `com.walkingrpg.walkingRpgMobile`; deployment target `14.0` |
| Signing declaration | Android и iOS: `external-protected-environment` |

## Synthetic restore evidence

Receipt явно содержит `scope=SYNTHETIC_CI`,
`productionValidated=false` и `actualProductionDrillRequired=true`. Он
фиксирует PostgreSQL `17.10`, Flyway `34`, 37 покрытых fixtures application
tables и exact совпадения source/restored:

- schema: `6c758caad9225115660eb0a47a68c2bc61ca29f1326f66c711dd9cd51fef680e`;
- data: `03cba3a8337ab1c8d954a7d10ead099946a0ab7e95fc8186e6bc8b4e6b5148e9`;
- sequences: `e0ca1b16b11db35b90e3eccba877939e6d59efa4f489b759098410001a3f2110`.

Synthetic dump намеренно не сохранён. Receipt не закрывает #154 и не является
real-backup restore evidence.

## F0 freeze и ownership handoff

Code-only baseline заморожен. Новый source scope до internal alpha разрешён
только для воспроизводимого release blocker, evidence-tooling gap, protected
configuration wiring или исправления, подтверждённого physical/alpha evidence.

| Workstream | Задачи | Требуемый внешний owner/action | Статус |
|---|---|---|---|
| Physical activity | [#149](https://github.com/MKSEgr/walking-rpg/issues/149), [#21](https://github.com/MKSEgr/walking-rpg/issues/21) | owner device matrix и доступ к physical iOS/Android/Watch/providers | `OWNER_ACTION_REQUIRED` |
| Identity | [#153](https://github.com/MKSEgr/walking-rpg/issues/153), [#175](https://github.com/MKSEgr/walking-rpg/issues/175) | Auth0/Telegram owner, tenant, bot и protected credentials | `OWNER_ACTION_REQUIRED` |
| Stage/recovery | [#151](https://github.com/MKSEgr/walking-rpg/issues/151), [#154](https://github.com/MKSEgr/walking-rpg/issues/154), [#155](https://github.com/MKSEgr/walking-rpg/issues/155) | infrastructure/incident owner, approved budget и protected environment | `OWNER_ACTION_REQUIRED` |
| Product/visual | [#156](https://github.com/MKSEgr/walking-rpg/issues/156) | product owner approval первого мира и питомцев | `PRODUCT_DECISION_REQUIRED` |
| Internal alpha | [#157](https://github.com/MKSEgr/walking-rpg/issues/157), [#161](https://github.com/MKSEgr/walking-rpg/issues/161), [#162](https://github.com/MKSEgr/walking-rpg/issues/162) | research owner, cohort, consent/support и decision authority | `OWNER_ACTION_REQUIRED` |
| Accounts/signing/distribution | [#152](https://github.com/MKSEgr/walking-rpg/issues/152), [#158](https://github.com/MKSEgr/walking-rpg/issues/158), [#159](https://github.com/MKSEgr/walking-rpg/issues/159), [#160](https://github.com/MKSEgr/walking-rpg/issues/160) | account/signing owner, developer access и protected signing environment | `OWNER_ACTION_REQUIRED` |

Dossier определяет обязательные роли и gates, но не назначает людей, не тратит
деньги, не создаёт аккаунты и не выдаёт credentials без решения владельца.

## External blockers и non-claims

Dossier доказывает только воспроизводимый `CODE_COMPLETE` engineering
baseline. Он **не утверждает**, что:

- Android/iOS artifacts production-signed или распространены;
- HealthKit/Health Connect проверены на физических устройствах;
- Auth0, Telegram, account lifecycle или destructive deletion прошли end to end;
- создан production-like stage, real TLS database, monitoring, restore или
  rollback drill;
- готовы developer accounts, public URLs, store declarations или review;
- подтверждены visual direction, понятность первого пути, retention или
  продуктовая ценность.

Порядок остаётся в [`FORWARD_ROADMAP.md`](../FORWARD_ROADMAP.md). Внешние
задачи остаются открытыми до собственного датированного evidence и acceptance.

## Stop и rollback

До merge PR #468 закрытие PR оставляет `alpha-rc2` не вступившим в силу.
После merge любое provenance mismatch или invalidated gate требует отдельного
release-blocker issue и пометки candidate revoked новым PR. Нельзя редактировать
эту запись, чтобы перенести label на другой source, anchor или tree.

## Acceptance evidence

- [x] Один tuple фиксирует post-merge anchor, artifact source и exact tree.
- [x] Standard CI, Release quality и finalizer успешны на accepted source.
- [x] Записаны пять artifact IDs, archive digests и независимо проверенные
      payload checksums.
- [x] Проверены build metadata и synthetic restore scope.
- [x] External gates сохранены как явные non-claims с owner-action handoff.
- [x] Изменения #468 ограничены release/evidence documentation.
