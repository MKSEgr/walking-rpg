# Release dossier `alpha-rc3`

[English version](alpha-rc3-release-dossier.md)

Этот dossier фиксирует baseline внешней валидации после завершения
gameplay-presentation track: принятое дерево исходников, его post-merge
`master` anchor, точные автоматические проверки и независимо проверенные
release artifacts. Это инженерный candidate record, а не доказательство
production signing, физических устройств, stage, магазинов или продуктовой
ценности.

## Decision record

| Поле | Значение |
|---|---|
| Candidate | `alpha-rc3` |
| Post-merge `master` anchor | [`ffd67f099256135ff0b9c7df5534516aa074bf74`](https://github.com/MKSEgr/walking-rpg/commit/ffd67f099256135ff0b9c7df5534516aa074bf74) |
| Source, создавший artifacts | [`dc2119a8305ecb7786f1c0a6fee8609d261f1195`](https://github.com/MKSEgr/walking-rpg/commit/dc2119a8305ecb7786f1c0a6fee8609d261f1195) |
| Exact content tree | `d622a8fc974f234c9a0744b9e99426a201dd2cad` |
| Принятое изменение | [PR #532](https://github.com/MKSEgr/walking-rpg/pull/532), authoritative saved journey decision event scenes |
| Время source для artifacts | `2026-08-30T07:19:54Z` |
| Время merge anchor | `2026-08-30T07:38:56Z` |
| Evidence проверено | `2026-08-30` |
| Recorder | выполнение Codex по [F0 issue #533](https://github.com/MKSEgr/walking-rpg/issues/533) |
| Decision authority | maintainer репозитория, вручную принимающий issue #533 через merge |

PR #532 смержен squash-методом. Merge изменил identity коммита, но полностью
сохранил принятое дерево: PR source и защищённый post-merge `master` anchor
имеют exact tree `d622a8fc974f234c9a0744b9e99426a201dd2cad`. Release
artifacts записали PR source и это дерево; merge commit фиксирует принятие и
интеграцию того же содержимого.

`alpha-rc3` означает весь tuple выше, а не branch или перемещаемый label.
Решение вступает в силу после merge PR, закрывающего issue #533. Запись нельзя
менять так, чтобы она указывала на другой source, anchor или tree. Для
преемника нужен новый candidate и отдельное evidence. Предыдущие записи
`alpha-rc1` и `alpha-rc2` остаются неизменяемыми историческими candidates.

## Exact automated gates

Source `dc2119a8305ecb7786f1c0a6fee8609d261f1195`, создавший artifacts, до
принятия PR #532 получил успешные Standard CI и Release quality runs.

| Gate | Run | Результат |
|---|---|---|
| Standard CI | [CI #1276 / run `33298949107`](https://github.com/MKSEgr/walking-rpg/actions/runs/33298949107) | `success` |
| Release quality | [Release quality #1157 / run `33298949103`](https://github.com/MKSEgr/walking-rpg/actions/runs/33298949103) | `success` |
| Release PR finalizer | [Finalizer #854 / run `33298949102`](https://github.com/MKSEgr/walking-rpg/actions/runs/33298949102) | `skipped` — не применим к source PR и не засчитан как пройденный gate |

Standard CI проверил структуру/Auth0 contracts, Java 21 compile, unit/API,
PostgreSQL integration/migrations, Flutter format/analyze/tests, Android debug
host и iOS simulator host. Release quality проверил policy/metadata, backend
package и protected container, synthetic PostgreSQL restore, Android unsigned
AAB и iOS no-codesign archive. Все пять CI jobs и все пять Release quality
jobs завершились успешно.

## Retained artifacts и digests

Все artifacts принадлежат Release quality run `33298949103`, содержат
`head_sha=dc2119a8305ecb7786f1c0a6fee8609d261f1195` и истекают
`2026-09-13`. Archive digest — GitHub SHA-256 скачанного ZIP. В ходе #533
каждый ZIP скачан повторно: его SHA-256 совпал с GitHub, а payload checksum
независимо пересчитан и совпал с checksum-файлом внутри artifact.

| Artifact | ID | Archive SHA-256 | Payload и проверенный SHA-256 |
|---|---:|---|---|
| `release-build-metadata` | `9728298321` | `5236ea86916f45001c8e9f09ed84c8189fd19e7b94f1386a5a9ef37c40d97227` | `build-metadata.json`: `3556946bab3f8b52f6aaa4c013d2df678f7142c140b8324d5f50ab105de9a630` |
| `synthetic-backup-restore-evidence` | `9728301025` | `97ac34f11b30e6c4c6586eb2887670ca95e3ca457c21798d7995b057764fd61a` | `evidence.json`: `b9de80bee2cc7ee63c436d48a06456ef0bad815cd92fa50953dcdf8930f7e457` |
| `backend-release-candidate` | `9728311533` | `9e482dd39bcdc2b803b4756c45ab8865721099ba5493d16a70ec418d2a8befa9` | `walking-rpg-backend-0.1.0-SNAPSHOT.jar`: `d1a7a566cb915899013b6482eb7e2c08127f8b5e6b33c4a44c6d5df66bdd6276` |
| `ios-no-codesign-release-app` | `9728337079` | `a1496a60e50a51c16c0c653184e66346d09b4678ecacf95e3b7d22f9d445d35f` | `WalkingRPG-no-codesign.zip`: `f4887059e9eb396ca11c3a1456f2d6a87b0924e44b0e627acbf4065b63ba9c77` |
| `android-unsigned-release-aab` | `9728392138` | `dbeddd86d510c6b8ca2930033039aac8e90226d8f03a35a745d47aaabc79593b` | `app-release.aab`: `c4c2605750a4445271f96d50d6866cc164531396a6537fa5221ccb7337ccaada` |

## Build metadata

| Поле | Значение |
|---|---|
| Application | `0.1.0+1` |
| Source / tree | `dc2119a8305ecb7786f1c0a6fee8609d261f1195` / `d622a8fc974f234c9a0744b9e99426a201dd2cad` |
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
- data: `ab1afab7e41a0f8592a2e86e466cd1f13054063e1c90c62972e5423082bf05c8`;
- sequences: `e0ca1b16b11db35b90e3eccba877939e6d59efa4f489b759098410001a3f2110`.

Synthetic dump намеренно не сохранён. Receipt не закрывает #154 и не является
real-backup restore evidence.

## F0 freeze и ownership handoff

Code-only baseline заморожен. Новый source scope до internal alpha разрешён
только для воспроизводимого release blocker, evidence-tooling gap, protected
configuration wiring или исправления, подтверждённого physical/alpha evidence.

| Workstream | Задачи | Требуемый внешний owner/action | Статус |
|---|---|---|---|
| Physical activity | [#21](https://github.com/MKSEgr/walking-rpg/issues/21) | owner device matrix и доступ к physical iOS/Android/Watch/providers | `OWNER_ACTION_REQUIRED` |
| Identity | [#153](https://github.com/MKSEgr/walking-rpg/issues/153), [#175](https://github.com/MKSEgr/walking-rpg/issues/175) | Auth0/Telegram owner, tenant, bot и protected credentials | `OWNER_ACTION_REQUIRED` |
| Stage/recovery | [#151](https://github.com/MKSEgr/walking-rpg/issues/151), [#154](https://github.com/MKSEgr/walking-rpg/issues/154), [#155](https://github.com/MKSEgr/walking-rpg/issues/155) | infrastructure/incident owner, approved budget и protected environment | `OWNER_ACTION_REQUIRED` |
| Product/visual | [#156](https://github.com/MKSEgr/walking-rpg/issues/156) | product owner approval первого мира и питомцев | `PRODUCT_DECISION_REQUIRED` |
| Internal alpha | [#161](https://github.com/MKSEgr/walking-rpg/issues/161), [#162](https://github.com/MKSEgr/walking-rpg/issues/162) | research owner, cohort, consent/support и decision authority | `OWNER_ACTION_REQUIRED` |
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

До merge закрытие PR для issue #533 оставляет `alpha-rc3` не вступившим в силу.
После merge любое provenance mismatch или invalidated gate требует отдельного
release-blocker issue и пометки candidate revoked новым PR. Нельзя редактировать
эту запись, чтобы перенести label на другой source, anchor или tree.

## Acceptance evidence

- [x] Один tuple фиксирует post-merge anchor, artifact source и exact tree.
- [x] Standard CI и Release quality успешны на accepted source; неприменимый
      skipped finalizer записан без ложного заявления о пройденном gate.
- [x] Записаны пять artifact IDs, archive digests и независимо проверенные
      payload checksums.
- [x] Проверены build metadata и synthetic restore scope.
- [x] External gates сохранены как явные non-claims с owner-action handoff.
- [x] Изменения #533 ограничены release/evidence documentation и F1 inventory
      baseline validator; application/runtime code не изменён.
