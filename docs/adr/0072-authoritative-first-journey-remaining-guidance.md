# ADR 0072: authoritative first-journey remaining guidance

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #411](https://github.com/MKSEgr/walking-rpg/issues/411)

## Контекст

Platform уже возвращает ordered onboarding catalog и accepted completed IDs.
Карточка показывала только дробь, поэтому игроку приходилось вычислять остаток.

## Решение

1. Mobile считает completed как пересечение catalog IDs и completed IDs.
2. Remaining — non-negative разность размера каталога и completed count.
3. Неполный путь получает exact RU/EN guidance, полный — нейтральное complete
   state без обещания награды.
4. Visible guidance исключена из semantics и добавлена к существующей route
   summary, поэтому progress и remaining объявляются ровно один раз.
5. Retired/non-catalog IDs остаются совместимыми, но не увеличивают progress.
6. Backend/API, порядок этапов, completion rules, resume command, persistence и
   rewards не меняются.

## Последствия

- общий прогресс понятен без ручного вычитания;
- неизвестные receipts не искажают accepted catalog projection;
- assistive technologies получают одну полную summary;
- server-owned onboarding rules остаются неизменными.

## Откат

Удалить derived counters, RU/EN guidance, coverage и documentation additions.
API, persisted data и migrations не затрагиваются.
