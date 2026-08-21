# ADR 0071: authoritative achievement collection guidance

- **Статус:** Accepted
- **Дата:** 2026-08-22
- **Связанная задача:** [issue #409](https://github.com/MKSEgr/walking-rpg/issues/409)

## Контекст

Platform journal показывал aggregate `unlocked / total`, используя полный
`userState.achievements`. Этот set содержит не только восемь catalog
achievement IDs, но и dynamic `season-reward-{level}` receipts. Поэтому после
получения сезонной награды aggregate мог завышать прогресс, а игрок всё равно
сам вычислял остаток до полного каталога.

## Решение

1. Mobile считает catalog achievement открытым только когда его exact stable
   ID одновременно присутствует в accepted catalog и user achievement set.
2. Dynamic и будущие non-catalog IDs остаются совместимыми state facts, но не
   участвуют в catalog count.
3. Remaining — non-negative разность длины accepted catalog и intersection
   count; отдельные unlock rules на клиент не переносятся.
4. RU/EN copy сообщает exact remaining либо факт полного набора без срока,
   наказания или reward promise.
5. Aggregate progress/guidance объединены в один semantics node. Отдельные
   tiles сохраняют собственные state semantics.
6. Platform API, backend catalog, persistence и achievement derivation не
   меняются.

## Последствия

- сезонные reward receipts больше не искажают видимый catalog progress;
- игрок видит точный остаток без самостоятельного вычитания;
- будущие server-owned IDs сохраняют forward compatibility;
- клиент не становится источником условий открытия достижений.

## Откат

Удалить derived intersection/remaining, новые RU/EN resources и aggregate
semantics wrapper. Backend, API и persistence rollback не нужны.
