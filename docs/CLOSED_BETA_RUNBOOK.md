# Closed beta runbook

## До набора участников

- release candidate прошёл standard CI и Release quality;
- физическая device matrix имеет evidence;
- privacy/store declarations опубликованы;
- crash ingestion и retention read model доступны;
- определены owner, support channel и incident window.

## Cohorts

Начинать с внутреннего cohort и расширять ступенчато. Для каждого этапа фиксируются build, число приглашённых и активных, дата старта и stop conditions.

## Метрики

- onboarding completion;
- D1/D7/D30 retention;
- activity sync success/retry rate;
- duplicate/idempotency conflicts;
- crash-free sessions/users;
- risk decision distribution и false positives;
- weekly route/quest completion;
- support incidents.

## Stop conditions

- потеря или дублирование экономики;
- массовый crash или невозможность старта;
- неверная обработка health totals/permissions;
- риск утечки данных;
- рост `BLOCK/REVIEW` без подтверждённого fraud;
- невозможность экспортировать или удалить аккаунт.

## Rollback

Остановить расширение cohort, отключить рискованные функции remote config, отозвать build, сохранить immutable evidence и выпустить исправление отдельным PR с новым build number.
