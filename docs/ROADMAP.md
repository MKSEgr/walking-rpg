# Roadmap

Roadmap отражает порядок снижения рисков, а не обещание конкретных календарных дат.

## Milestone 0 — Repository baseline

- [x] Зафиксировать концепцию
- [x] Создать Java backend shell
- [x] Создать Flutter mobile shell
- [x] Добавить архитектуру и ADR
- [x] Добавить локальный PostgreSQL
- [x] Создать удалённый Git-репозиторий
- [ ] Настроить branch protection
- [x] Добавить CI для структуры, Java backend и Flutter mobile

## Milestone 1 — Health API spike

- [ ] Зафиксировать минимальные версии iOS/Android
- [ ] Прочитать шаги из Apple Health
- [ ] Прочитать шаги из Health Connect
- [ ] Проверить телефон + часы
- [ ] Проверить ручной ввод
- [ ] Проверить удаление записи
- [ ] Проверить смену часового пояса
- [ ] Проверить background delivery
- [ ] Оценить расход батареи
- [ ] Выбрать Flutter plugin или собственный bridge

**Выход:** на реальных устройствах получаем стабильный агрегированный total без двойного учёта.

## Milestone 2 — Activity sync vertical slice

- [x] Спроектировать `/api/v1/activity/sync`
- [x] Добавить технические `app_user` и `app_device`
- [x] Добавить `activity_sync_state`
- [x] Добавить persistent idempotency
- [x] Рассчитать положительную дельту
- [x] Начислить ENERGY через wallet/ledger
- [x] Сериализовать конкурентные sync
- [x] Добавить unit/API/PostgreSQL tests
- [ ] Зафиксировать retention processed sync
- [ ] Подключить Health API mobile к activity sync

**Выход:** повторная синхронизация не создаёт повторную награду и сохраняет состояние после перезапуска.

## Milestone 3 — First playable

- [x] Production `GET /api/v1/home`
- [x] Flutter загружает server state
- [x] Один пилот
- [x] Один питомец
- [x] Одна экспедиция
- [x] Один узел
- [x] Энергия из шагов
- [x] Economy wallet и ledger
- [x] Атомарный debit ENERGY
- [x] Persistent expedition progress
- [x] Первое событие в статусе READY
- [ ] Выбор исхода события
- [ ] Одна награда за событие
- [ ] Persistent pilot/pet progression
- [ ] Экран результата события

**Выход:** пользователь проходит реальные шаги, тратит энергию и завершает одно игровое событие.

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
