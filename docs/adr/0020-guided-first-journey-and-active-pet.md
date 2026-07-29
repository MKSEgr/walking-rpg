# ADR 0020: Guided first journey and active pet

- Status: Accepted
- Date: 2026-07-29

## Context

Platform state содержал четыре onboarding step, но mobile показывал их как
отдельные кнопки «завершить» внутри Путевого журнала. Эти кнопки не доказывали,
что пользователь разрешил шаги, получил ENERGY, достиг узла или разрешил
событие. Выбор питомца также менял только `roadmap_user_state`: home и event
progression продолжали всегда показывать и награждать Искру.

Для alpha нужен честный первый десятиминутный маршрут, который знакомит с
основной петлёй игры и безопасно продолжается после потери сети или process
restart.

## Decision

- Authenticated mobile shell оборачивается в `FirstJourneyGate`.
- Канонический маршрут содержит шесть milestones:
  `welcome`, `health-permission`, `first-sync`, `pet-selection`,
  `first-expedition`, `first-event`.
- Milestone записывается после соответствующего реального действия. Отдельных
  пользовательских кнопок фиктивного завершения больше нет.
- Пользователь может выбрать «Продолжить позже» и вернуться к маршруту из
  Путевого журнала.
- Pending mutations используют существующий durable GAMEPLAY/ACTIVITY outbox.
  После restart mobile выводит подтверждаемые milestones из authoritative
  `home` и `platform` facts и идемпотентно backfill-ит отсутствующие отметки.
- Успешный activity sync подтверждается platform-фактом
  `hasSuccessfulActivitySync`, вычисляемым по зарегистрированному
  `app_device`. Запись устройства создаётся только внутри успешно завершившейся
  activity-транзакции и не удаляется вместе с идемпотентными receipts по
  retention policy. Поэтому sync с нулём шагов считается выполненным, а смена
  локальной даты не возвращает прошедшего onboarding пользователя к permission
  flow.
- Cached state остаётся read-only. Он может объяснить текущий этап, но не
  разрешает mutations или backfill.
- `SELECT_PET` атомарно меняет active pet и завершает `pet-selection`.
- `roadmap_user_state.activePetId` читается общей backend-границей
  `ActivePetProvider`. Home отображает выбранного питомца, event progression
  блокирует и награждает его отдельную `pet_progress` строку, а pilot XP
  остаётся общим.
- Bond из `CLAIM_QUEST` и уровень из `EVOLVE_PET` синхронизируются с
  `pet_progress` в той же транзакции. При чтении старого состояния provider
  объединяет platform progress с relational progress по максимуму, поэтому
  ранее полученные награды не теряются.
- При отсутствии или неизвестном старом state используется совместимый
  fallback `spark-v1`.
- Сюжетные тексты не называют Искру там, где пользователь мог выбрать Мха или
  Руну. Legacy `trust-spark` остаётся стабильным choice ID ради fingerprints и
  exact replay.
- Анимация и haptic feedback не входят в критический путь: их недоступность не
  задерживает authoritative reload.

## Consequences

- Onboarding completion теперь подтверждает прохождение основной игровой петли,
  а не нажатие служебных кнопок.
- Старый пользователь с уже разрешённым событием восстановит fact-backed
  milestones автоматически, но должен явно подтвердить выбор питомца.
- У каждого питомца независимые bond/level/version; переключение питомца не
  переносит между ними progression.
- Схема БД не меняется: используются существующие `roadmap_user_state` и
  составной ключ `pet_progress (user_id, pet_id)`.
- Physical-device проверка permission UX, темпа первых десяти минут и
  эмоциональной ценности выбора остаётся внешним alpha gate.
