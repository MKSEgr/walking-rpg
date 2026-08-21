# ADR 0068: authoritative skill unlock guidance

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #403](https://github.com/MKSEgr/walking-rpg/issues/403)

## Контекст

Platform уже возвращает принятый сезонный XP игрока и server-authored
`requiredSeasonXp` каждого навыка. Карточка закрытого навыка показывала только
общий порог, поэтому игроку приходилось самому вычислять остаток. Mobile parser
также принимал отрицательное требование, которое не имеет игрового смысла.

## Решение

1. Mobile fail-closed принимает skill content только при
   `requiredSeasonXp >= 0`; accepted user state уже требует non-negative
   `seasonXp`.
2. Presentation вычисляет только non-negative разность
   `requiredSeasonXp - seasonXp` и не хранит таблицу skill thresholds.
3. Locked unavailable skill показывает exact remaining одной короткой RU/EN
   строкой. Поскольку это единственный visual text с данным значением,
   assistive technologies получают его один раз без duplicate semantics.
4. Ready-to-unlock и unlocked skill сохраняют существующую requirement copy,
   кнопку, tooltip и server-backed unlock command boundary.
5. Backend, Platform API/schema, catalog, persistence, thresholds, unlock
   command, rewards и economy не меняются.

## Последствия

- близость открытия навыка понятна без ручного вычитания;
- некорректный отрицательный threshold не попадает в player-facing journal;
- mobile остаётся presentation consumer server-authored skill requirement;
- готовое и уже открытое состояния не меняют действие или смысл;
- compact large-text layout использует существующую вертикальную карточку.

## Откат

Удалить parser invariant, derived remaining method, RU/EN copy, coverage и
documentation additions. API, persisted data и migrations не затрагиваются.
