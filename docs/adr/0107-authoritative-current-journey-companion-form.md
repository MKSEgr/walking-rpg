# ADR 0107: authoritative current-journey companion form

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #503](https://github.com/MKSEgr/walking-rpg/issues/503)

## Контекст

Home snapshot уже содержит optional accepted active-companion `species` и
`evolutionStage`, а current-journey journal показывает identity и progression
того же спутника. Platform snapshot также проецирует active pet species/stage и
server-authored evolution thresholds с другой семантикой. Эти соседние
источники не должны восстанавливать или подменять current Home form.

## Решение

1. Journal читает species/evolution stage только из одного accepted Home
   snapshot и показывает label лишь при наличии обоих optional fields.
2. Known `petId` локализует mutable species через existing current-content
   resolver; legacy missing ID и unknown future ID сохраняют literal Home
   species.
3. Accepted non-negative stage использует existing RU/EN companion-form
   resolver. Mobile не применяет evolution thresholds и не прогнозирует
   следующую форму.
4. Platform active pet, decision/completion history, rewards и local catalog
   state не подменяют Home form.
5. Optional label получает одну dedicated semantics node без actions и
   выдерживает RU/EN compact large-text layout.
6. Home API, backend, persistence, commands, rewards, portraits и external
   validation не меняются.

## Последствия

- игрок видит accepted species и текущую форму рядом с companion identity и
  progression;
- known content локализуется, а будущий server content сохраняет literal
  species fallback;
- legacy snapshot с неполной optional парой не получает вымышленных данных;
- изменение полностью обратимо на mobile presentation уровне.

## Откат

Удалить journal form label, localization keys, tests и этот documentation
record. Home companion contract, progression и остальные pet surfaces останутся
без изменений.
