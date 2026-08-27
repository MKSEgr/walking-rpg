# ADR 0100: authoritative current-journey READY choice rewards

- **Статус:** Accepted
- **Дата:** 2026-08-26
- **Связанная задача:** [issue #489](https://github.com/MKSEgr/walking-rpg/issues/489)

## Контекст

Journal уже показывает accepted title и description доступных READY choices,
но не сохраняет видимый reward preview ожидающего решения. XP пилота, связь
спутника и optional material уже приходят в том же authoritative choice и
отображаются на Home. Восстановление наград из catalog, outcomes или history
создало бы второй client-owned источник.

## Решение

1. Reward preview читается только из `unlockedEvent` со status exact `READY`.
2. Награды принадлежат тому же accepted choice с `availability=AVAILABLE`, что
   и visible title/description. Server ordering сохраняется, locked choices
   исключаются, requirements не проверяются повторно.
3. Accepted `pilotExperienceReward` и `petBondReward` показываются буквально,
   включая zero, без clamp, агрегации или вывода результата выбора.
4. Optional `materialReward` использует accepted quantity. Known mutable item
   name локализуется через existing exact `itemId` resolver, unknown future ID
   сохраняет literal server fallback.
5. Legacy/empty, locked-only, absent, `RESOLVED` и unknown status не создают
   reward rows.
6. Event title, summary, count и каждая тройка choice title/description/rewards
   входят в одну semantics node в server order.
7. Journal остаётся read-only и не показывает requirements, correctness,
   consequences или actions. Reward resolution остаётся на Home/backend.
8. Phase, node, progress, route trail, decision log, topology и catalog rules
   не выбирают, не сортируют и не восстанавливают reward preview.

## Последствия

- ожидающее решение сохраняет полный accepted reward preview в журнале;
- pairing, ordering, eligibility и reward values остаются server-owned;
- known current material следует RU/EN locale, future item copy остаётся
  читаемой при несовпадении версий клиента и сервера;
- preview не обещает outcome и не становится вторым command surface.

## Откат

Удалить read-only reward rows, localization label, tests и documentation.
Existing READY event title/summary/count/choice title/description, Home actions,
backend contract, persistence и commands останутся без изменений.
