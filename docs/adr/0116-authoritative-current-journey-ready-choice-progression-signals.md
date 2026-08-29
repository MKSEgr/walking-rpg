# ADR 0116: authoritative current-journey READY choice progression signals

- **Статус:** Accepted
- **Дата:** 2026-08-29
- **Связанная задача:** [issue #523](https://github.com/MKSEgr/walking-rpg/issues/523)

## Контекст

Journal уже сохраняет literal reward preview и optional material emblem для
accepted available READY choices. Existing `ProgressionGainSignal` различает
pilot XP и companion bond по exact subject ID, но journal не связывает эти
reviewed marks с ожидающими reward channels. Выбор identity из Platform state,
names, amounts, history или catalog создал бы второй client-owned источник.

Backend при event resolution передаёт accepted reward amounts в progression:
XP получает starter pilot, а bond — текущий active pet. Тот же Home snapshot
уже содержит accepted `pilot.pilotId` и `pet.petId`. Эти IDs описывают текущий
preview context, но не являются immutable receipt будущего resolution.

## Решение

1. Signals читаются только для available choices accepted `unlockedEvent` со
   status exact `READY` в server order.
2. Positive `pilotExperienceReward` добавляет pilot-XP signal только при
   non-empty `pilot.pilotId` того же accepted Home snapshot. Positive
   `petBondReward` аналогично использует exact `pet.petId`.
3. Exact reward channel + subject ID передаются existing
   `ProgressionGainSignal`: known reviewed IDs выбирают established identity,
   unknown future IDs получают neutral fallback.
4. Zero channel и legacy snapshot без соответствующего subject ID не создают
   signal. Accepted numeric reward copy, включая zero, не меняется.
5. Locked choices, absent/non-READY/unknown event status и malformed snapshot
   не создают signals. Names, reward amount, Platform hero/pets, progression
   totals, route, decision history и catalog не восстанавливают identity.
6. Signals декоративны, остаются внутри existing event `ExcludeSemantics` и не
   дублируют combined READY-event accessibility label.
7. Journal остаётся read-only: signal не фиксирует будущего recipient, не
   прогнозирует level/bond result и не меняет Home/backend resolution.

## Последствия

- progression channels получили reviewed visual vocabulary рядом с literal
  reward preview;
- known current subjects различимы, future subjects остаются нейтральными, а
  legacy snapshot сохраняет читаемый reward text без ложной identity;
- accepted choice pairing, ordering, material art и single semantics остаются
  неизменными;
- API, backend, persistence, commands и assets не меняются.

## Откат

Удалить subject IDs из локального choice presentation record, decorative
signals, widget assertions и documentation. Existing READY choice signal,
copy, requirements, material emblem, Home actions и backend contract останутся
без изменений.
