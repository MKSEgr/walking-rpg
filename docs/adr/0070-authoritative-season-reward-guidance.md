# ADR 0070: authoritative season reward guidance

- **Статус:** Accepted
- **Дата:** 2026-08-21
- **Связанная задача:** [issue #407](https://github.com/MKSEgr/walking-rpg/issues/407)

## Контекст

Backend выдавал сезонные награды каждые 100 XP и вычислял `seasonLevel` тем же
шагом, но число оставалось в двух service expressions и в mobile claim
fallback. Platform catalog сообщал только число уровней. Поэтому mobile не мог
показать точный остаток до следующей награды, не превращая текущий баланс в
client-owned rule.

## Решение

1. Platform catalog публикует additive positive `season.xpPerLevel` рядом с
   `levels`; поле участвует в `catalogDigest`.
2. Backend использует один catalog-owned cadence для reward eligibility,
   snapshot `seasonLevel` и достижения третьего уровня сезона.
3. Mobile валидирует присутствующее значение как positive integer и только
   затем вычисляет следующий reward level и non-negative remaining XP.
4. RU/EN line показывает exact next level/remaining, не описывает reward
   contents и не меняет существующую claim action или seal semantics.
5. После final threshold guidance отсутствует. Legacy cached snapshot без
   поля сохраняет прежний 100-XP claim fallback для совместимости, но не
   получает inferred next-reward guidance.
6. Persisted state, migrations, reward payload и command protocol не меняются.

## Последствия

- игрок видит ближайшую сезонную цель без ручного вычисления;
- backend projection и validation больше не расходятся по скрытой константе;
- новый клиент fail-closed обрабатывает некорректный новый контракт;
- старый cache остаётся usable без ложной server-authoritative подсказки.

## Откат

Удалить `xpPerLevel` из catalog, вернуть service expressions и убрать mobile
derived guidance/tests. Persistence schema и migration rollback не нужны.
