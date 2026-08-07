# Walking RPG validation backlog

Этот реестр переводит [стратегическую оценку](PROJECT_ASSESSMENT_2026-08-07.md)
в проверяемые GitHub Issues. Он покрывает путь от текущего code-complete
alpha-candidate до решения `EXPAND`, `FIX_AND_RERUN` или `STOP` после internal
alpha.

Повторяемый способ работы описан в
[prompt «следующая задача → PR»](NEXT_TASK_TO_PR_PROMPT.md).

## Источник истины и статус

- Статус задачи определяется состоянием связанного GitHub Issue, а не
  чекбоксом в этом файле.
- Open issue без открытого PR — `READY` только когда все dependencies закрыты
  и нет внешнего blocker-а.
- Open issue со связанным PR — `IN_PROGRESS`.
- Closed issue — `DONE`, если он закрыт merge PR с `Closes #…` или принятым
  внешним evidence.
- Нехватка owner decision, устройства, account, credential или реального
  evidence означает `BLOCKED`, а не частичный pass.
- `CODE_COMPLETE` и `VALIDATED` — независимые статусы. Автоматические тесты не
  заменяют physical, deployment, store или cohort evidence.

## Bootstrap

`TASK-000 / E0 / W0.1` — PR, добавляющий assessment, этот backlog и рабочий
prompt. Его merge завершает reset источника истины и закрывает устаревшие
issues [#26](https://github.com/MKSEgr/walking-rpg/issues/26) и
[#29](https://github.com/MKSEgr/walking-rpg/issues/29). Активная physical
validation сохранена и нормализована в issue
[#21](https://github.com/MKSEgr/walking-rpg/issues/21).

## Активная программа до alpha gate

| Task | Issue | Epic / wave | Priority | Type | Проверяемый outcome | Dependencies |
|---|---:|---|---|---|---|---|
| TASK-001 | [#147](https://github.com/MKSEgr/walking-rpg/issues/147) | E0 / W0.2 | P0 | Release / governance | Exact `alpha-rc1` и интеграционный release dossier | TASK-000 merged |
| TASK-002 | [#148](https://github.com/MKSEgr/walking-rpg/issues/148) | E0 / W0.3 | P0 | Product decision | Owners, alpha decisions и feature-freeze policy | TASK-000 merged |
| TASK-003 | [#149](https://github.com/MKSEgr/walking-rpg/issues/149) | E1 / W1.1 | P0 | Manual prep | Реальная device/OS/provider matrix с owners | #147, #148 |
| TASK-004 | [#21](https://github.com/MKSEgr/walking-rpg/issues/21) | E1 / W1.2 | P0 | Manual validation | Physical HealthKit/Health Connect evidence | #147, #149, #158 |
| TASK-005 | [#150](https://github.com/MKSEgr/walking-rpg/issues/150) | E2 / W2.1 | P0 | Decision / config | Production IdP и auth contract без secrets | #148 |
| TASK-006 | [#151](https://github.com/MKSEgr/walking-rpg/issues/151) | E3 / W3.1 | P0 | Infrastructure | Protected production-like stage | #147, #148 |
| TASK-007 | [#152](https://github.com/MKSEgr/walking-rpg/issues/152) | E7 / W7.1 | P0 long-lead | Store external | Developer accounts, app IDs и public URLs | #148 |
| TASK-008 | [#153](https://github.com/MKSEgr/walking-rpg/issues/153) | E2 / W2.2 | P0 | Manual validation | Physical auth/account lifecycle E2E | #147, #150, #151, #158 |
| TASK-009 | [#154](https://github.com/MKSEgr/walking-rpg/issues/154) | E3 / W3.2 | P0 | Operations validation | Датированный real-backup restore | #151 |
| TASK-010 | [#155](https://github.com/MKSEgr/walking-rpg/issues/155) | E3 / W3.3 | P0 | Operations validation | Alert, stop и deployment rollback drill | #151, #154 |
| TASK-011 | [#156](https://github.com/MKSEgr/walking-rpg/issues/156) | E4 / W4.1 | P1 | Product research / decision | Утверждённое visual direction по physical evidence | #147, #149, #21 |
| TASK-012 | [#157](https://github.com/MKSEgr/walking-rpg/issues/157) | E5 / W5.1 | P1 | Research ops | Cohort, alpha protocol, thresholds и stop gates | #147, #148; status inputs #149, #150, #151 |
| TASK-013 | [#158](https://github.com/MKSEgr/walking-rpg/issues/158) | E7 / W7.2 | P1 long-lead | Release / store external | Protected signed internal candidates | #147, #150, #151, #152 |
| TASK-014 | [#159](https://github.com/MKSEgr/walking-rpg/issues/159) | E7 / W7.3 | P1 | Store / product | Metadata, declarations и launch assets | #148, #152, #156 |
| TASK-015 | [#160](https://github.com/MKSEgr/walking-rpg/issues/160) | E7 / W7.4 | P1 | Manual validation / release | Install, upgrade и distribution rollback evidence | #152, #158 |
| TASK-016 | [#161](https://github.com/MKSEgr/walking-rpg/issues/161) | E5 / W5.2 | P1 gate | Product research / validation | Internal alpha первых десяти минут | #21, #153, #154, #155, #156, #157, #158, #160 |
| TASK-017 | [#162](https://github.com/MKSEgr/walking-rpg/issues/162) | E5 / W5.3 | P1 gate | Product / release decision | `EXPAND`, `FIX_AND_RERUN` или `STOP` | #161, все release blockers resolved/rerun |

## Правило выбора следующей задачи

1. Если уже есть открытый PR по task issue, довести именно его до green и
   merge-ready; новую задачу не брать.
2. После merge убедиться, что `Closes #…` закрыл issue. Если GitHub не закрыл
   его автоматически, закрыть вручную только со ссылкой на merged PR.
3. Среди open issues выбрать наименьший `TASK-NNN`, у которого все указанные
   issue-dependencies закрыты.
4. Если задача внешне заблокирована, зафиксировать точный blocker и required
   owner action; не создавать фиктивный PR/evidence. Затем можно выбрать
   следующую готовую независимую задачу.
5. Одна задача — один логический Draft PR. Не смешивать backend, design,
   infrastructure и evidence без необходимости outcome-а.
6. PR обязан содержать `Closes #<issue>` и закрывать все acceptance criteria.
   До merge issue остаётся open.

## Evidence contract

Каждая задача хранит только минимально необходимое redacted evidence:

- exact source SHA, app/build version и environment;
- дата, owner и проверяемый result;
- device/OS/provider либо deployment/store/cohort context;
- workflow/log/screenshot/analytics references без secrets и персональных
  health/identity данных;
- deviations, defect issues и affected-scenario rerun;
- stop/rollback decision для рискованных операций.

Credentials, tokens, signing keys, provisioning material, raw health data и
verification documents не помещаются в GitHub Issues, PR, CI logs или Git.

## Следующая волна

E6 closed-beta issues не создаются заранее. Их разрешено нарезать только в
TASK-017 при решении `EXPAND`, используя фактические alpha findings и принятые
thresholds. E8 submission/rollout начинается после закрытия E6 и применимых E7
gates. E9 остаётся `DEFERRED`: новый feature становится задачей только с
проблемой, метрикой, ожидаемым outcome и kill criterion.
