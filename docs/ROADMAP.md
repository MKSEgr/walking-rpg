# Roadmap

Roadmap отражает порядок снижения рисков, а не обещание календарных дат.

## Milestone 0 — Repository baseline

- [x] Зафиксировать концепцию
- [x] Создать Java backend shell
- [x] Создать Flutter mobile shell
- [x] Добавить архитектуру и ADR
- [x] Добавить локальный PostgreSQL
- [x] Создать удалённый Git-репозиторий
- [ ] Настроить branch protection
- [x] Добавить CI для структуры, backend и mobile

## Milestone 1 — Health API spike

- [ ] Зафиксировать минимальные версии iOS/Android
- [ ] Выбрать Flutter plugin или собственный bridge
- [ ] Прочитать шаги из Apple Health
- [ ] Прочитать шаги из Health Connect
- [ ] Проверить телефон + часы
- [ ] Проверить ручной ввод и source metadata
- [ ] Проверить удаление записи
- [ ] Проверить смену часового пояса
- [ ] Проверить background delivery
- [ ] Оценить расход батареи

**Выход:** на реальных устройствах получаем стабильный cumulative total без двойного учёта.

## Milestone 2 — Activity sync vertical slice

- [x] Спроектировать `/api/v1/activity/sync`
- [x] Добавить технические `app_user` и `app_device`
- [x] Добавить `activity_sync_state`
- [x] Добавить persistent idempotency
- [x] Рассчитать положительную дельту
- [x] Начислить ENERGY через wallet/ledger
- [x] Сериализовать конкурентные sync
- [x] Добавить unit/API/PostgreSQL tests
- [x] Добавить Flutter `ActivityApiClient`
- [x] Добавить pluggable `StepSource` boundary
- [x] Проверить mobile → backend через явно включаемый development source
- [ ] Зафиксировать retention processed sync
- [ ] Подключить реальный Health API source

**Выход:** mobile отправляет authoritative reading в стабильный backend contract; замена development source на platform source не требует изменения API-клиента.

## Milestone 3 — First playable

- [x] Production `GET /api/v1/home`
- [x] Flutter загружает server state
- [x] Один пилот
- [x] Один питомец
- [x] Одна экспедиция
- [x] Один узел
- [x] ENERGY из шагов
- [x] Economy wallet и ledger
- [x] Атомарный debit ENERGY
- [x] Persistent expedition progress
- [x] Первое событие READY
- [x] Два варианта решения события
- [x] Одна постоянная награда за событие
- [x] Persistent pilot/pet progression
- [x] Экран результата события

**Выход:** пользователь получает шаги, тратит ENERGY, выбирает исход и завершает одно событие. Полный цикл проверен с development step source; real Health API остаётся отдельным hardware/platform риском.

## Milestone 4 — MVP content loop

- [ ] Персональная цель
- [ ] 15–20 узлов первой главы
- [ ] Три питомца
- [ ] Эволюция
- [ ] Навыки пилота
- [ ] Задания
- [ ] Достижения
- [ ] Инвентарь
- [ ] Push
- [ ] Remote config
- [ ] Базовая админка контента

## Milestone 5 — Closed beta

- [ ] Onboarding analytics
- [ ] D1/D7/D30
- [ ] Crash reporting
- [ ] Anti-fraud dashboard
- [ ] Баланс экономики
- [ ] Поддержка и удаление аккаунта
- [ ] Privacy policy
- [ ] 50–500 тестировщиков

## Milestone 6 — Soft launch

- [ ] Сезон
- [ ] Недельные маршруты
- [ ] Отряды
- [ ] Косметический магазин
- [ ] Платёжные интеграции
- [ ] Store review readiness
- [ ] A/B tests
