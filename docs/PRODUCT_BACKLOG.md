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

**Статус:** реализовано с PostgreSQL, wallet/ledger, multi-device lock, Flutter client и platform source. Остались persistent mobile queue, retention и attestation.

## P0 — first playable loop

### US-003. Получить ENERGY

Как пользователь, я хочу увидеть энергию прогулки, чтобы понимать связь движения и игры.

**Статус:** реализовано; mobile после sync перечитывает server-authoritative home.

### US-004. Продвинуть экспедицию

Как пользователь, я хочу потратить ENERGY и достичь первого узла.

**Статус:** реализовано для `starter-expedition-v1` с persistent progress и idempotent debit.

### US-005. Разрешить первое событие

Как пользователь, я хочу выбрать действие в событии и получить постоянный результат.

Критерии:

- событие разрешается один раз;
- выбор идемпотентен;
- результат хранится сервером;
- pilot XP и pet bond сохраняются;
- home показывает resolved outcome;
- поздняя ошибка откатывает progression и expedition completion.

**Статус:** реализовано для `signal-source-v1` с choices `analyze-signal` и `trust-spark`.

## P1 — после device validation

- persistent mobile command queue;
- персональная цель;
- второй узел;
- несколько типов событий;
- полноценный level-up и навыки;
- материалы и инвентарь;
- onboarding;
- push;
- базовая аналитика;
- offline read cache;
- background activity research.

## P2 — после подтверждения одиночного цикла

- отряды;
- недельный маршрут;
- косметика;
- сезон;
- расширенный антифрод;
- административное управление контентом.

## Icebox

- GPS-мир;
- PvP;
- открытый чат;
- маркетплейс;
- торговля питомцами;
- отдельные watch-приложения;
- 3D;
- криптовалюта.
