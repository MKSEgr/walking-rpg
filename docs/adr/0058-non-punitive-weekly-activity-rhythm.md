# ADR 0058: non-punitive weekly activity rhythm

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #383](https://github.com/MKSEgr/walking-rpg/issues/383)

## Контекст

Home показывает только сегодняшний прогресс и персональную дневную цель.
Product canon требует прогресс без наказания: несколько активных дней из семи,
нормальные дни отдыха и отсутствие разрушительного streak reset. Client-side
подсчёт из Health history не является authoritative и добавил бы новые
permission/timezone boundaries.

## Решение

1. Backend публикует additive `weeklyActivityRhythm` с `activeDays`,
   `windowDays`, `targetActiveDays` и derived `targetReached`.
2. Окно v1 содержит target local date и шесть предыдущих локальных дат.
   Активным считается день с persisted `activity_sync_state.accepted_total > 0`;
   current date входит после принятой activity sync.
3. Мягкая цель v1 равна четырём активным дням из семи. Пропущенный день не
   сбрасывает отдельное состояние: count меняется только при естественном
   движении rolling window.
4. Ритм не выдаёт ENERGY/rewards, не меняет daily goal и не является streak,
   achievement или Health permission boundary.
5. Mobile принимает legacy omission, fail-closed проверяет диапазоны и
   эквивалентность `targetReached == activeDays >= targetActiveDays`. RU/EN UI
   показывает server values и объединяет visible copy в одну semantics-строку.

## Последствия

- Home отвечает на исходную продуктовую гипотезу без новой persistence schema;
- текущий день и прошлые accepted totals читаются в том же repeatable-read
  Home snapshot;
- дни отдыха явно нормализованы и не обнуляют долгоживущий progression;
- цель 4/7 остаётся version-one product policy и может быть пересмотрена
  отдельным решением, не подменяясь client inference.

## Откат

Удалить additive projection, mobile model/UI, localizations, tests и
документацию. Таблицы и migration rollback не требуются.
