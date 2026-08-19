# ADR 0039: post-alpha gameplay track and Navigator canon

- **Статус:** Accepted
- **Дата:** 2026-08-19
- **Связанная задача:** [issue #337](https://github.com/MKSEgr/walking-rpg/issues/337)

## Контекст

`alpha-rc1` зафиксировал неизменяемый release baseline, а оставшиеся
production, store, physical-device и user-validation gates требуют внешних
credentials, устройств или участников. Product Owner временно не может вести
эту внешнюю часть, но явно разрешил продолжить автономную разработку игры.
Такая работа не должна переписывать alpha evidence или создавать ложный
статус `VALIDATED`.

Одновременно утверждённый violet companion уже является Навигатором в art
canon, но current server copy по-прежнему называла stable `rune-v1` «Руной».
Отдельный stable pilot `navigator-v1` тоже носит имя «Навигатор», поэтому
paired crew copy требовала однозначного role label.

## Решение

После alpha продолжается отдельный code-only gameplay track на `master`:

1. `alpha-rc1`, его SHA/tree, receipts и release evidence остаются
   неизменяемой исторической границей;
2. внешние issues и roadmap gates остаются открытыми, пока не появится
   датированное реальное evidence;
3. каждая следующая gameplay slice получает собственные issue, draft PR,
   документацию и автоматизированные проверки.

Первый slice канонизирует current player-facing companion copy:

- `rune-v1` остаётся stable companion ID; внутренние enum, database identity и
  `companion_rune_*` asset paths не меняются;
- current forms — «Навигатор», «Навигатор потоков» и «Навигатор созвездий»;
- current trait — «Точный проводник»;
- `navigator-v1` остаётся stable pilot ID и сохраняет имя «Навигатор» в
  portrait/profile/dossier контексте;
- paired crew copy использует role label «Пилот»;
- deployed Flyway migrations, immutable receipts и historical release/runbook
  records не переписываются.

## Последствия

- сервер, first-journey localization и текущие gameplay routes используют один
  companion canon без breaking ID migration;
- cached/historical payloads с прежним display text остаются читаемыми как
  persisted literal data;
- идентичные имена пилота и спутника не создают «Навигатор и Навигатор» в
  paired crew UI;
- post-alpha работа может продолжаться независимо от внешних launch gates, но
  не приближает их статус к `VALIDATED` без соответствующего evidence.

## Откат

Current display copy можно вернуть отдельным content/mobile изменением без
schema rollback. Stable IDs, assets, historical migrations и `alpha-rc1`
receipts при таком откате не изменяются.
