# Product backlog

## P0 — physical Health validation

### US-001. Получить реальные шаги

Как пользователь, я хочу разрешить приложению читать мои шаги, чтобы реальная прогулка влияла на игру.

Критерии:

- разрешение запрашивается в контексте пользы;
- отказ не ломает home screen;
- читается cumulative total текущего локального дня;
- несколько источников не создают клиентское суммирование;
- удаление/коррекция platform record не создаёт отрицательную награду;
- Android и iOS используют один `StepSource` domain contract;
- mobile не отправляет сырые health samples;
- результат проходит через существующий server-authoritative sync.

**Статус:** код, tests, Android APK и iOS Simulator build готовы. Физические iPhone/Android и телефон + часы не проверены.

### US-002. Идемпотентно синхронизировать активность

Как система, я хочу принимать cumulative authoritative total и начислять только новую активность.

**Статус:** реализовано с PostgreSQL, wallet/ledger, multi-device lock, Flutter client, platform source, foreground durable outbox, retention и shadow-mode risk/attestation signals.

## P0 — first playable loop

### US-003. Получить ENERGY

Как пользователь, я хочу увидеть энергию прогулки, чтобы понимать связь движения и игры.

**Статус:** реализовано; mobile после sync перечитывает server-authoritative home.

### US-004. Продвинуть экспедицию

Как пользователь, я хочу тратить ENERGY и последовательно достигать узлов экспедиции.

**Статус:** реализовано для 18 последовательных узлов
`starter-expedition-v1` с persistent progress и idempotent debit.

### US-005. Разрешить первое событие

Как пользователь, я хочу выбрать действие в событии и получить постоянный результат.

Критерии:

- событие разрешается один раз;
- выбор идемпотентен;
- результат хранится сервером;
- pilot XP и pet bond сохраняются;
- home показывает resolved outcome;
- поздняя ошибка откатывает progression и expedition completion.

**Статус:** реализовано для `signal-source-v1` с choices `analyze-signal` и
стабильным legacy id `trust-spark` (пользовательский текст «Довериться
питомцу»); после resolution открывается второй узел.

### US-006. Завершить второй узел и получить material reward

Как пользователь, я хочу разрешить второе событие и сохранить найденный материал, чтобы экспедиция давала накопительный предметный результат.

Критерии:

- второй узел открывается после первого события без потери progression;
- advance использует существующий ENERGY ledger и idempotency;
- второе событие имеет два server-owned выбора;
- material reward выдаётся один раз и записывается в inventory ledger;
- home возвращает inventory stack и immutable reward snapshot;
- пользователи `starter-v1` мигрируют на второй узел без повторной награды;
- durable outbox replay-ит second-event command с исходным key.

**Статус:** реализовано для `lumen-gate` / `echo-vault-v1`, items `lumen-shard` и `echo-thread`.

### US-007. Получить персональную дневную цель

Как пользователь, я хочу получать достижимую цель относительно собственной активности, а не общий порог для всех.

Критерии:

- backend использует предыдущие семь локальных дней, не включая текущий;
- baseline — медиана положительных accepted total;
- цель растёт на 5%, округляется до 250 и ограничивается диапазоном 2 000–12 000;
- пока валидных дней меньше трёх, используется стартовая цель 6 000;
- mobile показывает понятное объяснение источника цели;
- `GET /home` остаётся read-only.

**Статус:** policy `adaptive-median-v1`, API metadata и Flutter explanation реализованы; продуктовая проверка параметров остаётся частью device/beta validation.

### US-008. Пройти честный первый путь

Как новый пользователь, я хочу за один понятный маршрут подключить шаги,
получить ENERGY, выбрать питомца, достигнуть узла и принять решение.

Критерии:

- этапы завершаются реальными игровыми действиями;
- выбранный питомец появляется в home и получает event bond;
- маршрут можно отложить и безопасно продолжить после restart;
- подтверждаемые этапы восстанавливаются из server facts;
- cached state не разрешает mutations;
- анимация и вибрация не блокируют progression.

**Статус:** код и автоматические tests готовы. Server-authoritative milestones
и cohort read model измеряют conversion и time-to-value; фактический темп первых
10 минут, permission UX и эмоциональная ценность требуют alpha validation на
физических устройствах.

## P1 — расширение MVP

Технически реализованы:

- первая глава из 18 последовательных узлов;
- три питомца, active selection, эволюция и навыки;
- onboarding, задания и достижения;
- development push provider boundary;
- product analytics и experiment exposure;
- read-only offline cache валидированных `home` / `platform` snapshots.

После физической device-validation и beta остаются продуктовые расширения:

- дополнительные типы событий и нелинейные ветки;
- расход материалов, crafting и unique items;
- production APNs / FCM;
- background activity research с battery evidence;
- настройка баланса по фактическим retention/economy данным.

## P2 — soft-launch capabilities

Технически реализованы season, weekly route, squads, cosmetics, sandbox payment boundary, risk/admin read models и базовый content/remote-config admin API.

До включения этих функций в публичный релиз остаются:

- production store billing и server-side purchase verification;
- production push;
- полноценный операторский UI для контента, anti-fraud и cohorts;
- beta-проверка отрядов, сезонной экономики и косметики;
- rollout/rollback и support-процессы.

## Icebox

- GPS-мир;
- PvP;
- открытый чат;
- маркетплейс;
- торговля питомцами;
- отдельные watch-приложения;
- 3D;
- криптовалюта.
