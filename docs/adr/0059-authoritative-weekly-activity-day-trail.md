# ADR 0059: authoritative weekly activity day trail

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #385](https://github.com/MKSEgr/walking-rpg/issues/385)

## Контекст

Мягкий недельный ритм из ADR 0058 показывает count и цель 4/7, но не объясняет,
какие именно даты сформировали результат. Client-side лента из Health history
нарушила бы authoritative boundary и добавила permission, clock и timezone
inference; streak-графика превратила бы нормальный отдых в отрицательный сигнал.

## Решение

1. Backend расширяет `weeklyActivityRhythm` полем `days`: ровно семь элементов
   `{localDate, active}` в порядке от target `localDate - 6` до target date.
2. `active=true` задаётся только persisted строкой
   `activity_sync_state.accepted_total > 0`. Дата без такой строки публикуется
   как нейтральный rest day; step total наружу не передаётся.
3. Trail строится внутри существующего repeatable-read Home snapshot. Размер,
   continuity и число active entries проверяются доменным контрактом.
4. Mobile принимает legacy weekly object без `days`. Если поле присутствует,
   parser fail-closed проверяет типы, ISO local dates, длину, порядок, endpoint
   относительно Home `localDate` и соответствие `activeDays`.
5. RU/EN UI показывает компактные walking/rest markers. Rest использует
   нейтральный tone, а одна semantics summary классифицирует все семь дат без
   duplicate announcements.

## Последствия

- игрок видит форму rolling week без нового persisted streak state;
- API остаётся additive, а старый mobile продолжает читать count 4/7;
- отсутствие activity не становится ошибкой, penalty, ENERGY или reward;
- дата и active flag остаются server-owned, mobile не обращается к Health
  history и не достраивает отсутствующую ленту.

## Откат

Удалить additive `days` projection, mobile markers/validation, tests и
документацию. Persistence schema и migration rollback не требуются.
