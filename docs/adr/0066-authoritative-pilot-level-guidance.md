# ADR 0066: authoritative pilot level guidance

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #399](https://github.com/MKSEgr/walking-rpg/issues/399)

## Контекст

Home уже возвращает уровень пилота, текущий XP и порог следующего уровня из
server-authoritative progression. Mobile показывал только `current / target`,
поэтому игроку приходилось самому вычислять остаток. Парсер также принимал
невозможные сочетания этих полей, хотя backend progression поддерживает
положительный уровень и порог, неотрицательный current XP и `current < next`.

## Решение

1. Mobile parser принимает pilot progression только при `level > 0`,
   `currentExperience >= 0`, `nextLevelExperience > currentExperience` и
   fail-closed отклоняет невозможный API snapshot до rendering/cache handoff.
2. После этой проверки presentation вычисляет только точный остаток
   `next - current` и bounded visual ratio `current / next`.
3. RU/EN карточка показывает current, target и remaining XP одной нейтральной
   строкой. Visual progress исключён из semantics, чтобы exact state
   объявлялся ровно один раз.
4. Legacy/internal direct snapshot без валидного порога сохраняет прежний
   literal `current / target` fallback и не получает inferred remaining или
   progress indicator.
5. Backend, Home API/schema, persistence, thresholds, level-up и rewards не
   меняются; mobile не обещает награду и не мутирует progression.

## Последствия

- близость следующего уровня понятна без ручного вычитания;
- impossible progression не попадает в player-facing Home или read-only cache;
- доступность сохраняет точную XP-информацию без generic percentage duplicate;
- compact/large-text layout получает ту же вертикальную reflow-модель карточки;
- server остаётся единственным владельцем порогов, level-up и наград.

## Откат

Удалить parser invariant, derived getters, RU/EN state, visual indicator,
coverage и documentation additions. API, persisted data и migrations не
затрагиваются.
