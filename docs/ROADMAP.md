# Roadmap

Roadmap отражает порядок снижения рисков, а не обещание конкретных календарных дат.

## Milestone 0 — Repository baseline

- [x] Зафиксировать концепцию
- [x] Создать Java backend shell
- [x] Создать Flutter mobile shell
- [x] Добавить архитектуру и ADR
- [x] Добавить локальный PostgreSQL
- [x] Создать удалённый Git-репозиторий
- [x] Добавить CI для структуры, backend и Flutter
- [x] Добавить Android/iOS host build jobs
- [ ] Настроить branch protection

## Milestone 1 — Platform Health API

### Реализация

- [x] Зафиксировать iOS 14 deployment target
- [x] Зафиксировать Android minSdk 26
- [x] Выбрать adapter за `StepSource`
- [x] Добавить Apple HealthKit foreground source
- [x] Добавить Health Connect foreground source
- [x] Запрашивать только STEPS READ
- [x] Добавить Android Activity Recognition flow
- [x] Получать IANA timezone
- [x] Подключить platform source к существующему activity sync
- [x] Зафиксировать host-проекты в репозитории
- [x] Собрать Android debug APK в CI
- [x] Собрать iOS Simulator app в CI

### Device validation

- [ ] Проверить iPhone без Apple Watch
- [ ] Проверить iPhone + Apple Watch
- [ ] Проверить Android + Health Connect
- [ ] Проверить несколько Android data providers
- [ ] Проверить ручной ввод
- [ ] Проверить удаление/коррекцию записи
- [ ] Проверить отзыв разрешения
- [ ] Проверить смену часового пояса
- [ ] Проверить переход через полночь
- [ ] Оценить расход батареи
- [ ] Исследовать background delivery

**Выход:** на целевых физических устройствах получаем стабильный aggregated total без двойного учёта. Код и builds готовы, device exit criteria ещё не закрыты.

## Milestone 2 — Activity sync vertical slice

- [x] Спроектировать `/api/v1/activity/sync`
- [x] Добавить `app_user`, `app_device`, `activity_sync_state`
- [x] Добавить persistent idempotency
- [x] Рассчитать положительную delta
- [x] Начислить ENERGY через wallet/ledger
- [x] Сериализовать конкурентные multi-device sync
- [x] Добавить unit/API/PostgreSQL tests
- [x] Подключить Flutter client
- [x] Подключить platform `StepSource`
- [ ] Зафиксировать retention processed sync
- [ ] Добавить persistent mobile command queue
- [ ] Добавить attestation/risk score

**Выход:** повторная синхронизация не создаёт повторную награду и сохраняет состояние после backend restart.

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
- [x] Два server-owned выбора
- [x] Идемпотентное разрешение события
- [x] Persistent pilot XP и pet bond
- [x] Экран результата события

**Выход:** пользователь проходит шаги, тратит энергию, выбирает решение и получает постоянную награду. Закрыто технически; реальный device-source требует Milestone 1 validation.

## Milestone 4 — MVP content loop

- [ ] Персональная цель
- [ ] Второй узел и переход после первого события
- [ ] 15–20 узлов первой главы
- [ ] Три питомца
- [ ] Эволюция
- [ ] Навыки пилота
- [ ] Материалы и инвентарь
- [ ] Задания
- [ ] Достижения
- [ ] Onboarding
- [ ] Push
- [ ] Remote config
- [ ] Базовая админка контента

## Milestone 5 — Closed beta

- [ ] Onboarding analytics
- [ ] D1/D7/D30
- [ ] Crash reporting
- [ ] Anti-fraud dashboard
- [ ] Баланс экономики
- [ ] Удаление аккаунта и экспорт данных
- [ ] Privacy policy и store declarations
- [ ] 50–500 тестировщиков

## Milestone 6 — Soft launch

- [ ] Сезон
- [ ] Недельные маршруты
- [ ] Отряды
- [ ] Косметический магазин
- [ ] Платёжные интеграции
- [ ] Store review readiness
- [ ] A/B tests
