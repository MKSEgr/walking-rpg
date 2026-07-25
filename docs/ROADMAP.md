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
- [ ] Принять решение: готовый Flutter-плагин или собственный bridge

**Выход:** на реальных устройствах получаем стабильный агрегированный total без двойного учёта.

## Milestone 2 — Activity sync vertical slice

- [x] Спроектировать контракт `/api/v1/activity/sync`
- [x] Добавить технические `app_user` и `app_device`
- [x] Добавить persistent sync response как первую ingestion-запись
- [x] Добавить `activity_sync_state`
- [x] Добавить in-memory idempotency spike
- [x] Перенести idempotency в PostgreSQL
- [x] Рассчитать положительную дельту
- [x] Добавить базовые диагностические risk status
- [x] Добавить unit/API tests для contract spike
- [x] Добавить PostgreSQL integration tests
- [x] Сериализовать конкурентные sync через user-level PostgreSQL advisory lock
- [ ] Зафиксировать retention для processed sync
- [ ] Подключить mobile к backend

**Выход:** повторная синхронизация не создаёт повторную награду и сохраняет состояние после перезапуска.

## Milestone 3 — First playable

- [ ] Один пилот
- [ ] Один питомец
- [ ] Одна экспедиция
- [ ] Один узел
- [ ] Энергия из шагов
- [ ] Одно событие
- [ ] Одна награда
- [ ] Ledger
- [ ] Экран результата

**Выход:** пользователь проходит реальные шаги и завершает одно игровое событие.

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
