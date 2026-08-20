# API draft

Документ фиксирует работающие MVP-контракты, но пока не заменяет полноценную OpenAPI-спецификацию.

## Общие правила

- namespace: `/api/v1`;
- JSON-поля: camelCase;
- даты/время: ISO-8601;
- внешние UUID принимаются только в полном формате `8-4-4-4-12`; регистр hex
  незначим, response использует каноническую lowercase-форму, а сокращённые
  алиасы возвращают `400 VALIDATION_ERROR` до application service;
- enum-like protocol tokens (`commandType`, impression, platform, provider,
  cohort status) канонизируются независимо от JVM/OS locale; lowercase ASCII
  input всегда приводит к одному uppercase token;
- команды изменения поддерживают idempotency;
- клиент не передаёт рассчитанную награду, баланс, progress или progression;
- ошибки имеют `code`, `message`, `details`, `traceId`;
- production API использует `Authorization: Bearer <access-token>`; `userId`, actor и activity device identity вычисляются backend-ом из authenticated context;
- signed OIDC `sub` принимается только как исходная JSON-строка: compact JWS
  payload проверяется до Nimbus/Spring registered-claim conversion; `sub`,
  actor и stable device claim не обрезаются: граничный whitespace, control characters и
  `sub`/actor длиннее persistent limit отклоняются как
  `401 AUTHENTICATION_ERROR` до controller; отсутствующий optional actor/device
  claim разрешён, но присутствующий claim с пустым значением, неверным типом
  или сломанным nested-path отклоняется fail-closed;
  тот же контракт применяется к защищённому `/actuator/prometheus` без lookup
  состояния игрового аккаунта;
- локальные `X-User-Id` / `X-Device-Id` разрешены только в явном профиле `local` с `dev-header`; production-профиль их игнорирует;
- пользовательские endpoint-ы требуют `ROLE_USER`, `/api/v1/admin/**` требует `ROLE_ADMIN`.

## `GET /api/v1/system/info`

Проверка запущенного backend.

## `GET /api/v1/account/export`

Возвращает полный JSON-экспорт данных текущего authenticated subject. Mobile
создаёт временный JSON-файл, передаёт его через системный share sheet и удаляет
локальную staging-копию после закрытия sheet. Постоянное место сохранения
выбирает пользователь в системном интерфейсе.
Экспорт включает `firstJourneyMilestones` с milestone, source, минимальными
игровыми attributes и timestamps, а также `uniqueInventory`,
`craftingOperations` и `craftingIngredients` без access tokens или локального
mobile outbox. Refined unique item содержит `rarity`/`upgradedAt`, а immutable
операции входят в `itemUpgradeOperations` и `itemUpgradeIngredients`.
Persistent loadout и его exact command snapshots входят в `equipment` и
`equipmentOperations`; cosmetic loadout входит в `cosmeticEquipment`.
Current expedition cycle и immutable start receipts входят в
`expeditionJourney` и `expeditionJourneyOperations`.
До формирования файла backend на одном database connection захватывает
session-level subject lock, затем на том же connection начинает read-only
`REPEATABLE_READ`. Первый statement возвращает PostgreSQL
`statement_timestamp()` как `exportedAt` и фиксирует snapshot; затем backend
проверяет deletion registry и читает все секции. Поэтому конкурентная игровая
команда не смешивает в одном экспорте состояния до и после своего commit,
рассинхронизация JVM clock не сдвигает метку snapshot, а удаление либо
сериализуется после export, либо уже завершённая deletion receipt даёт
`410 ACCOUNT_DELETED`. Export не резервирует второй pool slot и работает при
`DB_POOL_SIZE=1`.

```http
Authorization: Bearer <access-token>
Accept: application/json
```

## `POST /api/v1/account/deletion-requests`

Синхронно удаляет игровые данные authenticated subject и возвращает постоянную
квитанцию. Перед запросом mobile выполняет интерактивную OIDC-проверку той же
учётной записи с `prompt=login` и `max_age=0`, затем двухэтапное
пользовательское подтверждение.

```http
Authorization: Bearer <fresh-access-token>
Idempotency-Key: account-delete-7a35d4bbf64f4e7ca441e59b61eb9ec4
Content-Type: application/json
```

```json
{
  "confirmation": "DELETE"
}
```

```json
{
  "receiptId": "11111111-1111-1111-1111-111111111111",
  "status": "COMPLETED",
  "requestedAt": "2026-07-29T05:00:00Z",
  "completedAt": "2026-07-29T05:00:00Z",
  "replayed": false
}
```

Backend принимает destructive request только если подписанный access token
содержит `auth_time` не старше
`ACCOUNT_DELETION_MAX_AUTH_AGE` (по умолчанию `PT5M`). Отсутствующий,
некорректный или устаревший claim возвращает
`403 FRESH_AUTHENTICATION_REQUIRED`. Production IdP обязан включать
стандартный OIDC `auth_time` в access token. NumericDate преобразуется без
floating-point округления и сохраняет допустимую дробную часть до наносекунды,
когда decoder предоставляет точный `BigDecimal` или `Instant`. Потенциально
потерявшие исходную signed decimal точность `Float`/`Double`, выходящие за
диапазон `Instant` и sub-nanosecond значения отклоняются до account mutation.

Повтор после потери ответа возвращает ту же квитанцию с `replayed=true`, в том
числе после перезапуска клиента. Backend хранит только SHA-256 subject и
idempotency key, UUID квитанции и timestamps; raw OIDC subject в квитанции не
сохраняется.

После создания квитанции остальные authenticated endpoints для этого subject
проверяются общим security filter до controller и возвращают
`410 ACCOUNT_DELETED`, включая `/api/v1/admin/**`. Поэтому старый Bearer token
не может пересоздать игровой аккаунт, читать административные данные или
выполнять привилегированные операции. Сам deletion endpoint остаётся доступен
для idempotent replay квитанции. Bearer transport воспринимает этот код как
окончательное удаление и запускает fail-closed локальную очистку без refresh.

## `GET /api/v1/home/demo`

Явное демонстрационное состояние. Production mobile не использует его как silent fallback.

## `GET /api/v1/home?localDate=YYYY-MM-DD`

Возвращает актуальный read-model главного экрана.

```http
Authorization: Bearer <access-token>
```

После capable-разрешения второго события и до явного acknowledgement response
содержит накопленный inventory, следующий узел и durable результат события:

```json
{
  "localDate": "2026-07-26",
  "timeZone": "Europe/Berlin",
  "dailySteps": 10000,
  "dailyGoal": 3250,
  "dailyGoalPolicy": {
    "policyVersion": "adaptive-median-v1",
    "source": "ADAPTIVE",
    "baselineSteps": 3000,
    "sampleDays": 3,
    "lookbackDays": 7,
    "minimumSampleDays": 3,
    "defaultGoal": 6000,
    "growthPercent": 5,
    "roundingStep": 250,
    "minimumGoal": 2000,
    "maximumGoal": 12000
  },
  "availableEnergy": 25,
  "activityStateVersion": 1,
  "economyVersion": 3,
  "lastActivitySyncAt": "2026-07-26T06:55:00Z",
  "serverTime": "2026-07-26T07:00:00Z",
  "contentVersion": "chapter-1-v2",
  "pilot": {
    "pilotId": "navigator-v1",
    "name": "Навигатор",
    "level": 1,
    "currentExperience": 90,
    "nextLevelExperience": 100,
    "specialization": "Не выбрана"
  },
  "pet": {
    "petId": "spark-v1",
    "name": "Искра",
    "species": "Люмин",
    "level": 1,
    "bond": 23,
    "evolutionStage": 0,
    "trait": "Чуткий разведчик"
  },
  "inventory": [
    {
      "itemId": "lumen-shard",
      "name": "Люминовый осколок",
      "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
      "quantity": 2,
      "version": 1,
      "kind": "MATERIAL",
      "itemInstanceId": null,
      "equippableSlotId": null,
      "equippedSlotId": null
    }
  ],
  "equipment": [
    {
      "slotId": "NAVIGATION",
      "name": "Навигационный прибор",
      "description": "Один уникальный инструмент, влияющий на доступные маршруты.",
      "status": "EMPTY",
      "version": 0,
      "item": null
    }
  ],
  "craftingRecipes": [
    {
      "recipeId": "resonance-compass-v1",
      "recipeVersion": "1",
      "name": "Собрать резонансный компас",
      "description": "Соединить световое ядро с живой нитью маршрута.",
      "status": "MISSING_MATERIALS",
      "ingredients": [
        {
          "itemId": "lumen-shard",
          "name": "Люминовый осколок",
          "requiredQuantity": 2,
          "availableQuantity": 2
        },
        {
          "itemId": "echo-thread",
          "name": "Нить эха",
          "requiredQuantity": 1,
          "availableQuantity": 0
        }
      ],
      "result": {
        "itemId": "resonance-compass",
        "name": "Резонансный компас",
        "description": "Уникальный прибор, собранный из люминовых осколков и нити эха.",
        "kind": "UNIQUE"
      }
    }
  ],
  "pendingEventResult": {
    "receiptId": "22222222-2222-2222-2222-222222222222",
    "eventId": "echo-vault-v1",
    "eventTitle": "Хранилище эха",
    "choiceId": "stabilize-core",
    "choiceTitle": "Стабилизировать ядро",
    "outcomeTitle": "Стабильный резонанс",
    "outcomeSummary": "Ядро перестало разрушаться, а два люминовых осколка сохранили его энергию.",
    "pilot": {
      "pilotId": "navigator-v1",
      "name": "Навигатор",
      "level": 1,
      "experienceGained": 30,
      "currentExperience": 90,
      "nextLevelExperience": 100,
      "version": 2
    },
    "pet": {
      "petId": "spark-v1",
      "name": "Искра",
      "level": 1,
      "bondGained": 8,
      "bond": 23,
      "version": 2
    },
    "material": {
      "itemId": "lumen-shard",
      "name": "Люминовый осколок",
      "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
      "quantityGained": 2,
      "quantityAfter": 2,
      "version": 1
    },
    "nextNode": {
      "nodeId": "ash-orbit",
      "name": "Пепельная орбита"
    },
    "resolvedAt": "2026-07-26T07:00:00Z"
  },
  "expedition": {
    "expeditionId": "starter-expedition-v1",
    "name": "Сигнал из туманного сектора",
    "currentNodeId": "ash-orbit",
    "currentNode": "Пепельная орбита",
    "progress": 0,
    "requiredEnergy": 55,
    "status": "IN_PROGRESS",
    "version": 4,
    "journeyNumber": 2,
    "routeTrail": [
      {
        "nodeId": "outer-beacon",
        "nodeName": "Внешний маяк",
        "state": "VISITED",
        "decision": {
          "choiceId": "analyze-signal",
          "choiceTitle": "Разобрать сигнал",
          "outcomeTitle": "Карта отклика"
        }
      },
      {
        "nodeId": "lumen-gate",
        "nodeName": "Люминовые ворота",
        "state": "VISITED",
        "decision": {
          "choiceId": "stabilize-core",
          "choiceTitle": "Стабилизировать ядро",
          "outcomeTitle": "Ровный импульс"
        }
      },
      {
        "nodeId": "ash-orbit",
        "nodeName": "Пепельная орбита",
        "state": "CURRENT"
      }
    ],
    "decisionLog": [
      {
        "eventId": "outer-beacon-v1",
        "eventTitle": "Сигнал у границы",
        "choiceId": "analyze-signal",
        "choiceTitle": "Разобрать сигнал",
        "outcomeTitle": "Карта отклика",
        "outcomeSummary": "Навигатор сохранил безопасный путь к маяку.",
        "pilotExperienceGained": 40,
        "petId": "spark-v1",
        "petName": "Искра",
        "petBondGained": 5,
        "materialReward": null,
        "resolvedAt": "2026-07-26T06:20:00Z"
      },
      {
        "eventId": "lumen-gate-v1",
        "eventTitle": "Сердце маяка",
        "choiceId": "stabilize-core",
        "choiceTitle": "Стабилизировать ядро",
        "outcomeTitle": "Ровный импульс",
        "outcomeSummary": "Маяк удержал безопасный курс.",
        "pilotExperienceGained": 20,
        "petId": "spark-v1",
        "petName": "Искра",
        "petBondGained": 15,
        "materialReward": {
          "itemId": "lumen-shard",
          "itemName": "Люмен-осколок",
          "quantity": 2
        },
        "resolvedAt": "2026-07-26T07:00:00Z"
      }
    ],
    "completionRecap": null,
    "recentJourneyRecaps": [],
    "journeyChronicle": null,
    "unlockedEvent": null
  }
}
```

Семантика:

- activity относится к `user + localDate`;
- `dailyGoal` рассчитывается backend-ом по медиане положительных accepted total за предыдущие семь локальных дней;
- при менее чем трёх валидных днях возвращается стартовая цель `6000`;
- текущий день не участвует в собственной цели;
- `dailyGoalPolicy` объясняет baseline и параметры политики; при чётном числе дней `baselineSteps` может содержать `.5`;
- ENERGY, expedition, progression и inventory глобальны для пользователя;
- `pilot.pilotId` — additive stable identity текущего пилота. Mobile разрешает
  известный ID через выбранный RU/EN catalog; legacy snapshot без поля,
  неизвестный ID и copy от более нового backend сохраняют literal `name` без
  попытки определить identity по display text;
- имена текущей экспедиции, узлов route trail, питомца, inventory/equipment,
  recipes и upgrades разрешаются mobile только по их существующим stable IDs.
  У известного `expedition.unlockedEvent` со status `READY` mobile разрешает
  title/summary по exact `eventId`, а title/description/requirement выбора — по
  exact `eventId + choiceId`. Неизвестные ID сохраняют server literal. Event со
  status `RESOLVED`, selected choice, outcome, durable result, decision log и
  recap остаются persisted literal history и не переписываются при смене
  locale;
- `expedition.journeyNumber` — положительный persistent номер текущего
  прохождения; legacy response без поля трактуется mobile как первый
  поход;
- `expedition.routeTrail[]` — упорядоченный server-owned след только текущего
  похода. Он содержит уже обработанные event nodes со state `VISITED` и одну
  последнюю точку `CURRENT` либо `COMPLETED`, не раскрывает будущие развилки и
  не смешивает результаты других `journeyNumber`. Additive nullable
  `decision` у разрешённой точки содержит stable `choiceId` и persisted
  `choiceTitle + outcomeTitle` из той же ordered immutable event resolution;
  завершённая последняя точка сохраняет annotation после смены state на
  `COMPLETED`, а ещё не разрешённый `CURRENT` не получает выдуманного выбора.
  Legacy response без `routeTrail` не показывает карту, а без `decision`
  сохраняет прежний вид узла;
- `expedition.decisionLog[]` — упорядоченный журнал уже принятых решений только
  текущего похода. Заголовки события, выбора и исхода, описание результата и
  `resolvedAt` читаются из immutable event resolution, поэтому republish или
  rollback контента не переписывает прошлое. Additive reward fields содержат
  фактически выданные XP пилота, stable identity/name питомца, связь и nullable
  material reward из той же записи; mobile не восстанавливает их из текущего
  content или totals. Новый `journeyNumber` начинает пустой журнал, а legacy
  response без журнала либо без reward fields остаётся валидным. Flutter
  показывает persisted `resolvedAt` каждой записи как locale-aware RU/EN
  local-time label и переиспользует его в accessibility summary; client clock,
  cache metadata и время Home-response не участвуют;
- `expedition.completionRecap` — additive nullable итог только завершённого
  текущего похода. Он содержит тот же `journeyNumber`, число immutable
  resolutions, суммы фактически выданных XP пилота и связи питомцев, а также
  ordered `materials[]`, сгруппированные по persisted `itemId + itemName`.
  Для любого незавершённого или только что начатого похода значение равно
  `null`; legacy response без поля остаётся валидным. Пример completed shape:

  ```json
  {
    "journeyNumber": 1,
    "decisionCount": 1,
    "decisions": [
      {
        "eventId": "signal-source-v1",
        "eventTitle": "Источник сигнала",
        "choiceId": "analyze-signal",
        "choiceTitle": "Разобрать сигнал",
        "outcomeTitle": "Карта отклика",
        "outcomeSummary": "Маршрут к люминовым воротам сохранён.",
        "pilotExperienceGained": 40,
        "petId": "spark-v1",
        "petName": "Искра",
        "petBondGained": 5,
        "materialReward": {
          "itemId": "lumen-shard",
          "itemName": "Люмен-осколок",
          "quantity": 2
        },
        "resolvedAt": "2026-07-26T06:12:00Z"
      }
    ],
    "finalDecision": {
      "eventId": "signal-source-v1",
      "eventTitle": "Источник сигнала",
      "choiceId": "analyze-signal",
      "choiceTitle": "Разобрать сигнал",
      "outcomeTitle": "Карта отклика",
      "outcomeSummary": "Маршрут к люминовым воротам сохранён.",
      "resolvedAt": "2026-07-26T06:12:00Z"
    },
    "durationSeconds": 4320,
    "pilotExperienceGained": 40,
    "pilotExperienceRewards": [
      {
        "pilotId": "navigator-v1",
        "pilotName": "Навигатор",
        "experienceGained": 40
      }
    ],
    "petBondGained": 5,
    "petBondRewards": [
      {
        "petId": "spark-v1",
        "petName": "Искра",
        "bondGained": 5
      }
    ],
    "materials": [
      {
        "itemId": "lumen-shard",
        "itemName": "Люмен-осколок",
        "quantity": 2
      }
    ]
  }
  ```

  Additive ordered `pilotExperienceRewards[]` группирует положительный
  фактически выданный XP exact journey по persisted `pilotId + pilotName` в
  порядке первого появления. Сумма `experienceGained` точно равна
  совместимому `pilotExperienceGained`. Если historical resolution не
  содержит полной persisted pilot identity, backend опускает весь массив;
  legacy response без поля остаётся валидным и показывает общий XP без имени.
  Additive `petBondRewards[]` группирует только положительную сохранённую связь
  по persisted `petId + petName` в порядке первого появления. Сумма
  `bondGained` равна совместимому общему `petBondGained`; legacy response без
  массива остаётся валидным и показывает общий итог без имён питомцев.
  Additive nullable `finalDecision` — последняя immutable event resolution в
  порядке `expedition_version, receipt_id`; её event/choice/outcome copy и
  `resolvedAt` не перечитываются из current content. Legacy response без поля
  остаётся валидным и просто не показывает финал. Flutter использует тот же
  persisted `resolvedAt` как completion moment current и recent recap:
  переводит instant в локальную timezone только для locale-aware RU/EN
  presentation и ничего не выводит при legacy omission. Client clock, cache
  timestamp и время Home-response не подменяют этот факт.
  Additive nullable `durationSeconds` содержит целые секунды между
  persisted start exact journey и `finalDecision.resolvedAt`. Journey 1
  использует initial cycle/progress `created_at`, journey 2+ — immutable
  `processed_expedition_journey_start.server_time`. Backend опускает поле
  при missing start/final или start позже final; legacy response без поля
  остаётся валидным. Client clock, cache/Home-response time и current content
  не участвуют в расчёте.
  Additive ordered `decisions[]` содержит те же полные persisted записи, что
  current `decisionLog`: event/choice/outcome copy, `resolvedAt` и фактически
  выданные XP, pet bond identity и nullable material reward. Массив строится
  только из immutable resolutions exact `journeyNumber`; при наличии его длина
  равна `decisionCount`, а последняя запись совпадает с `finalDecision`.
  Раскрытая archive history показывает время каждой записи по тем же
  presentation-only правилам, что current `decisionLog`. Legacy recap без
  массива остаётся валидным.

- `expedition.recentJourneyRecaps[]` — не более пяти итогов предыдущих
  завершённых походов, от нового к старому. Факт завершения определяется
  immutable receipt старта следующего `journeyNumber`, поэтому старый
  `expedition_status=COMPLETED` внутри event resolution после расширения главы
  не добавляет незавершённый или текущий поход в архив. Награды агрегируются
  из persisted event resolutions соответствующего похода по тем же правилам,
  что `completionRecap`, включая ordered `pilotExperienceRewards[]`,
  `petBondRewards[]` и persisted `finalDecision`. Additive `decisions[]`
  позволяет раскрыть полную сохранённую историю архивного похода без lookup
  current content или восстановления topology; legacy response без поля
  читается как пустой архив;

- `expedition.journeyChronicle` — additive nullable lifetime-итог всех
  подтверждённых завершённых походов этого пользователя и экспедиции:
  `completedJourneyCount`, `decisionCount`, nullable non-negative
  `totalDurationSeconds`, nullable non-negative `longestDurationSeconds`,
  nullable positive `longestJourneyNumber`, nullable ISO-8601 instant
  `longestJourneyCompletedAt`, nullable non-negative `averageDurationSeconds`,
  `pilotExperienceGained` и `petBondGained`.
  `totalDurationSeconds` суммирует полные целые секунды каждого included
  journey: journey 1 начинается в initial cycle/progress creation, journey 2+
  — в exact journey-start receipt `server_time`, а заканчивается последней
  immutable resolution exact journey. Любая отсутствующая или обратная
  граница опускает весь lifetime duration без частичного итога.
  `longestDurationSeconds` выбирает maximum из тех же exact boundaries,
  публикуется только вместе с total и не превышает его. Additive
  `longestJourneyNumber` указывает journey этого maximum; tie выбирается по
  меньшему номеру, поле публикуется только вместе с longest и не превышает
  `completedJourneyCount`. Additive `longestJourneyCompletedAt` берётся из
  immutable final resolution exact winning journey и публикуется только
  вместе с longest duration и identity. Current authoritative `COMPLETED`
  сравнивается ровно один раз и заменяет record identity и completion instant
  только при строго большей duration; tie сохраняет historical winner.
  `averageDurationSeconds`
  вычисляется после того же current merge как целочисленное floor-деление
  `totalDurationSeconds / completedJourneyCount`, публикуется только вместе с
  total и не выводится из recent archive или client clock. Additive
  ordered `pilotExperienceRewards[]` группирует
  положительный фактически выданный XP по persisted `pilotId + pilotName` в
  порядке первого immutable появления; сумма `experienceGained` точно равна
  совместимому общему `pilotExperienceGained`. Additive `petBondRewards[]`
  группирует только положительную
  сохранённую связь по persisted `petId + petName` в порядке первого
  immutable появления; сумма `bondGained` точно равна совместимому общему
  `petBondGained`. Additive ordered `materials[]` группирует положительные
  reward facts по persisted `itemId + itemName` в порядке первого immutable
  появления. Additive ordered `decisionOutcomes[]` группирует все immutable
  resolutions по persisted `eventId + eventTitle + choiceId + choiceTitle +
  outcomeTitle`, хранит положительный `decisionCount` и сохраняет порядок
  первого появления решения. Additive ordered `finaleOutcomes[]` выбирает
  последнюю immutable resolution каждого завершённого похода, группирует
  persisted
  `eventId + eventTitle + choiceId + choiceTitle + outcomeTitle` и хранит
  положительный `journeyCount` в порядке первого появления финала. Для прошлых
  походов completion proof — immutable receipt старта следующего
  `journeyNumber`; текущий поход входит в итог только при
  authoritative `COMPLETED` и объединяется с историческими breakdown ровно
  один раз. Агрегат не ограничен пятью строками архива и суммирует rewards
  только из persisted event resolutions, не перечитывая current content,
  inventory или текущие progression totals. До первого подтверждённого
  финиша значение равно `null`; legacy response без `journeyChronicle`,
  `totalDurationSeconds`, `longestDurationSeconds`, `longestJourneyNumber`,
  `longestJourneyCompletedAt`, `averageDurationSeconds`,
  `pilotExperienceRewards`, `petBondRewards`, `materials`,
  `decisionOutcomes` или `finaleOutcomes` остаётся валидным. При наличии
  pilot-массива его
  `experienceGained` в сумме точно равен общему `pilotExperienceGained`; при
  наличии decision-массива его `decisionCount` в сумме точно равен общему
  `decisionCount`; при наличии finale-массива его `journeyCount` в сумме
  точно равен `completedJourneyCount`. Пример:

  ```json
  {
    "completedJourneyCount": 8,
    "decisionCount": 19,
    "totalDurationSeconds": 65700,
    "longestDurationSeconds": 12600,
    "longestJourneyNumber": 7,
    "longestJourneyCompletedAt": "2026-07-25T12:00:00Z",
    "averageDurationSeconds": 8212,
    "pilotExperienceGained": 476,
    "petBondGained": 133,
    "pilotExperienceRewards": [
      {
        "pilotId": "navigator-v1",
        "pilotName": "Навигатор",
        "experienceGained": 410
      },
      {
        "pilotId": "archivist-v1",
        "pilotName": "Архивариус",
        "experienceGained": 66
      }
    ],
    "petBondRewards": [
      {
        "petId": "spark-v1",
        "petName": "Искра",
        "bondGained": 80
      },
      {
        "petId": "moss-v1",
        "petName": "Мох",
        "bondGained": 53
      }
    ],
    "materials": [
      {
        "itemId": "echo-thread",
        "itemName": "Эхо-нити",
        "quantity": 37
      },
      {
        "itemId": "ash-seed",
        "itemName": "Пепельное семя",
        "quantity": 12
      }
    ],
    "decisionOutcomes": [
      {
        "eventId": "signal-source-v1",
        "eventTitle": "Внешний сигнал",
        "choiceId": "analyze-signal",
        "choiceTitle": "Разобрать сигнал",
        "outcomeTitle": "Карта отклика",
        "decisionCount": 12
      },
      {
        "eventId": "mirror-delta-v1",
        "eventTitle": "Зеркальная дельта",
        "choiceId": "follow-reflection",
        "choiceTitle": "Следовать за отражением",
        "outcomeTitle": "Отражение принято",
        "decisionCount": 7
      }
    ],
    "finaleOutcomes": [
      {
        "eventId": "echo-vault-v1",
        "eventTitle": "Сердце маяка",
        "choiceId": "stabilize-core",
        "choiceTitle": "Стабилизировать ядро",
        "outcomeTitle": "Ровный импульс",
        "journeyCount": 5
      },
      {
        "eventId": "mirror-delta-v1",
        "eventTitle": "Зеркальная дельта",
        "choiceId": "follow-reflection",
        "choiceTitle": "Следовать за отражением",
        "outcomeTitle": "Отражение принято",
        "journeyCount": 3
      }
    ]
  }
  ```

- неизвестный пользователь получает zero-state и starter content;
- `pet.petId` — стабильный server-owned идентификатор активного питомца, а
  `pet.evolutionStage` — authoritative стадия из platform state; legacy state
  без сохранённой стадии проецируется как `0`;
- `inventory[]` содержит актуальные material stacks и unique items;
  `kind=MATERIAL|UNIQUE`, unique item всегда имеет `quantity=1`; для unique
  item additive fields содержат persistent `itemInstanceId`, допустимый
  `equippableSlotId`, nullable текущий `equippedSlotId` и nullable для legacy
  client `rarity`;
- `equipment[]` — additive server-owned projection slot state; `status`
  принимает `EMPTY|EQUIPPED`, а `item` присутствует только для `EQUIPPED`;
- в `expedition.unlockedEvent` legacy-массив `choices` содержит только
  доступные варианты; additive `lockedChoices` содержит недоступные gated
  варианты с `availability=LOCKED` и server-owned `requirement`. Новый mobile
  объединяет массивы для UI, старый mobile игнорирует locked choices. Для
  открытого READY event локализация narrative использует только exact
  `eventId + choiceId`; `availability` и requirement facts остаются
  authoritative server state;
- `craftingRecipes[]` — additive server-owned projection; `status` принимает
  `READY`, `MISSING_MATERIALS` или `CRAFTED`, а available quantities отражают
  тот же repeatable-read snapshot, что и inventory;
- `itemUpgrades[]` — additive server-owned projection active content-а;
  `status` принимает `LOCKED`, `MISSING_MATERIALS`, `READY` или `COMPLETED`,
  содержит target level/rarity и authoritative ingredient quantities;
- `pendingEventResult` — nullable top-level receipt единственного
  неподтверждённого результата текущей экспедиции; он содержит immutable
  choice/reward snapshot и nullable `nextNode`;
- `serverTime` приходит из первого PostgreSQL `statement_timestamp()` и
  обозначает observation boundary того же `REPEATABLE_READ` snapshot, а не
  время завершения последнего Home query или сериализации HTTP-ответа;
- результат остаётся доступен после reload/restart, даже когда authoritative
  expedition уже перешла на следующий узел; после acknowledgement конкретного
  receipt он исчезает из pending projection;
- `GET` не выполняет `INSERT` или `UPDATE`.

## `POST /api/v1/activity/sync`

Принимает cumulative authoritative total, сохраняет дневной high-watermark и начисляет ENERGY через ledger.

```http
Authorization: Bearer <access-token>
```

Request:

```json
{
  "localDate": "2026-07-26",
  "timeZone": "Europe/Berlin",
  "authoritativeTotal": 6842,
  "buckets": [],
  "syncCursor": "opaque-cursor",
  "idempotencyKey": "device-date-sequence",
  "attestation": null
}
```

Response:

```json
{
  "acceptedTotal": 6842,
  "acceptedDelta": 6842,
  "energyGranted": 68,
  "energyBalanceAfter": 68,
  "economyVersion": 1,
  "riskStatus": "ACCEPTED",
  "stateVersion": 1,
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Формула:

```text
energyGranted = floor(newAcceptedTotal / 100)
              - floor(previousAcceptedTotal / 100)
```

`riskStatus`:

```text
ACCEPTED
NO_NEW_ACTIVITY
TOTAL_DECREASED
```

Повтор одного key и payload возвращает исходный response. Тот же key с другим business payload возвращает `409 IDEMPOTENCY_CONFLICT`.

`authoritativeTotal` и `buckets[].steps` — обязательные JSON-поля с
неотрицательным целым значением. Явный `0` допустим, но отсутствующее поле или
`null` возвращает `400 VALIDATION_ERROR` до создания user/device state,
activity high-watermark, ENERGY ledger или durable idempotency receipt. Поэтому
повреждённая mobile-команда не может быть принята как успешный zero-sync и
заблокировать исправленный retry тем же key.

Оба поля проходят exact signed-`long` conversion непосредственно из JSON
number. Математически целая decimal-запись (`100.0`) допустима, но ненулевая
дробная часть, строковый JSON type (`"100"`) и значение вне диапазона `long`
возвращают `400 VALIDATION_ERROR` до controller, state и receipt. Поэтому
Jackson scalar coercion не может молча превратить отличающийся transport
payload в другую business-команду.

Exact replay и сравнение payload действуют, пока durable
`processed_activity_sync` receipt находится в retention window. После его
очистки прежний key больше не имеет сохранённого response и при повторном
использовании начинает новую operation generation. ENERGY source identity для
новых операций имеет вид `v2:<requestFingerprint>`, поэтому такая generation
не сталкивается с append-only ledger entry удалённого receipt и возвращает
актуальный wallet snapshot. Сохраняемый дневной high-watermark по-прежнему не
позволяет повторно начислить уже принятые шаги; raw health payload в ledger не
записывается.

`attestation` не входит в business fingerprint и может быть перевыпущен между
сетевыми попытками. Поэтому backend создаёт отдельный shadow-mode risk
assessment для каждого exact replay до возврата сохранённого response; replay
не повторяет ENERGY credit и не меняет activity high-watermark.
Risk assessment использует checked arithmetic для суммы `buckets[].steps` и
порога резкого `8×` роста. Если сумма bucket-ов не помещается в signed `long`,
она fail-closed учитывается как `BUCKET_TOTAL_MISMATCH`; переполнение порога не
может скрыть mismatch или создать ложный multiplier signal.

Для новой синхронизации `serverTime` фиксируется после общего user lock.
Проверка `localDate`, device presence, shadow risk assessment, ENERGY ledger и
durable response используют одно значение. Тем же временем датируются
`activity_sync_state.updated_at`, который проецируется как Home
`lastActivitySyncAt`, и retention-key `processed_activity_sync.created_at`.
Поэтому ожидавший lock request не может быть датирован или удалён как будто он
предшествовал уже завершённой serialized command. Exact replay возвращает
исходный business response; новый request-scoped risk assessment попытки
получает текущее post-lock время.

`localDate` может быть текущей или прошлой датой в заявленной IANA `timeZone`.
Дата, которая ещё не наступила по серверному времени в этой зоне, отклоняется
до создания user/device/state/ledger с `400 VALIDATION_ERROR` и
`details.field = localDate`. `timeZone` должна входить в установленный IANA/TZDB
registry; произвольный fixed offset (`+18:00`, `UTC+18:00`) возвращает
`400 VALIDATION_ERROR` с `details.field = timeZone`.

## `POST /api/v1/expeditions/{expeditionId}/advance`

Тратит ENERGY на persistent progress экспедиции.

```http
Authorization: Bearer <access-token>
```

Request:

```json
{
  "energyToSpend": 30,
  "idempotencyKey": "starter-expedition-v1-advance-1"
}
```

Response после достижения узла:

```json
{
  "contentVersion": "chapter-1-v2",
  "expeditionId": "starter-expedition-v1",
  "expeditionName": "Сигнал из туманного сектора",
  "energySpent": 30,
  "energyBalanceAfter": 38,
  "economyVersion": 2,
  "progressAfter": 30,
  "requiredEnergy": 30,
  "expeditionVersion": 1,
  "status": "EVENT_READY",
  "currentNodeId": "outer-beacon",
  "currentNodeName": "Внешний маяк",
  "unlockedEvent": {
    "eventId": "signal-source-v1",
    "title": "Источник сигнала",
    "summary": "Маяк отвечает повторяющимся импульсом.",
    "status": "READY"
  },
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Для новой, ещё не обработанной команды `serverTime` фиксируется после общего
user+expedition lock. ENERGY debit/ledger, expedition progress и durable
response используют одно post-lock значение, поэтому ожидавший lock advance не
может быть датирован раньше уже завершённой serialized mutation той же
экспедиции. Exact replay возвращает исходный `serverTime` без повторного debit.

Правила:

- `energyToSpend > 0`;
- `energyToSpend` проходит тот же exact signed-`long` JSON-number contract:
  целая decimal-запись допустима, дробное, строковое или выходящее за диапазон
  значение отклоняется до ENERGY debit и durable receipt;
- amount не превышает остаток до узла;
- partial advance разрешён;
- wallet не становится отрицательным;
- пока существует неподтверждённый `pendingEventResult` этой экспедиции, новый
  advance возвращает `409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED`: сначала
  пользователь должен подтвердить durable receipt;
- после `EVENT_READY` новый advance возвращает `409 EXPEDITION_STATE_CONFLICT`;
- после первого event resolution тот же endpoint продвигает второй узел `lumen-gate` с порогом 45;
- account-deletion subject lock и active check удерживаются в той же
  транзакции до expedition lock, replay lookup, debit и progress mutation;
- debit, ledger, progress и response сохраняются одной транзакцией.

## `POST /api/v1/expeditions/{expeditionId}/journeys`

Начинает следующий поход после `COMPLETED`. Команда не списывает
ENERGY: первый узел снова получает `IN_PROGRESS`, и обычный `advance`
по-прежнему требует ENERGY.

```json
{
  "expectedJourneyNumber": 2,
  "idempotencyKey": "starter-expedition-v1-journey-3"
}
```

```json
{
  "contentVersion": "chapter-1-v17",
  "expeditionId": "starter-expedition-v1",
  "expeditionName": "Сигнал из туманного сектора",
  "journeyNumber": 3,
  "progressAfter": 0,
  "requiredEnergy": 30,
  "expeditionVersion": 61,
  "status": "IN_PROGRESS",
  "currentNodeId": "outer-beacon",
  "currentNodeName": "Внешний маяк",
  "serverTime": "2026-08-17T06:00:00Z"
}
```

Правила:

- `expectedJourneyNumber` защищает от stale-команды со второго устройства;
- exact replay того же key возвращает исходный response даже после
  перехода в `IN_PROGRESS`;
- новая команда разрешена только из `COMPLETED` и при отсутствии
  `pendingEventResult`;
- пилот, питомец, эволюция, навыки, inventory и equipment не
  изменяются;
- stale/незавершённое состояние возвращает
  `409 EXPEDITION_JOURNEY_STATE_CONFLICT` с `status`,
  `expectedJourneyNumber` и `currentJourneyNumber`.

## `POST /api/v1/events/{eventId}/resolve`

Разрешает открытое событие одним из server-owned вариантов и атомарно применяет progression/material reward.

```http
Authorization: Bearer <access-token>
X-Walking-RPG-Capabilities: durable-event-result-v1
```

Request:

```json
{
  "choiceId": "stabilize-core",
  "idempotencyKey": "echo-vault-v1-resolution-1"
}
```

Первые два события сохраняют stable IDs в `chapter-1-v2`:

```text
signal-source-v1
  analyze-signal  → +40 pilot XP, +5 pet bond, переход к lumen-gate
  trust-spark     → +20 pilot XP, +15 pet bond, переход к lumen-gate
                    (стабильный legacy id; UI: «Довериться питомцу»)

echo-vault-v1
  stabilize-core  → +30 pilot XP, +8 pet bond, +2 lumen-shard, переход к ash-orbit
  follow-echo     → +20 pilot XP, +18 pet bond, +1 echo-thread, переход к ash-orbit

mirror-delta-v1
  обычные choices   → переход к storm-archive
  follow-resonance  → требует resonance-compass в NAVIGATION,
                      +35 pilot XP, +16 pet bond, +1 dawn-fragment,
                      переход к optional resonance-pocket

resonance-pocket-v1
  любой choice      → награда optional node и возврат к storm-archive

spectrum-observatory-v1 (chapter-1-v6)
  trace-second-dawn → требует prism-sextant уровня 2 в NAVIGATION,
                      +46 pilot XP, +24 pet bond, +3 dawn-fragment,
                      возврат к horizon-spire

dawn-relay-v1 (chapter-1-v7)
  open-second-dawn  → требует prism-sextant уровня 2 в NAVIGATION,
                      +48 pilot XP, +26 pet bond, +1 dawn-fragment,
                      переход к optional second-dawn-threshold

second-dawn-threshold-v1
  anchor-second-dawn → +60 pilot XP, +22 pet bond, +2 ion-bloom,
                       завершение экспедиции
  leap-beyond-dawn   → +42 pilot XP, +34 pet bond, +2 dawn-fragment,
                       завершение экспедиции
  cross-uncharted-verge (chapter-1-v9)
                     → требует prism-sextant уровня 3 в NAVIGATION,
                       +58 pilot XP, +32 pet bond, +2 echo-thread,
                       переход к optional uncharted-verge

uncharted-verge-v1 (chapter-1-v9)
  deploy-return-beacon → +72 pilot XP, +28 pet bond, +3 prism-dust,
                         завершение экспедиции
  follow-living-constellation
                       → +50 pilot XP, +42 pet bond, +3 dawn-fragment,
                         завершение экспедиции

uncharted-verge-v1 (additive chapter-1-v10 choices)
  ignite-star-trail    → требует активную Искру,
                         +48 pilot XP, +46 pet bond, +3 ion-bloom,
                         завершение экспедиции
  root-return-beacon   → требует активного Мха,
                         +64 pilot XP, +34 pet bond, +3 ash-seed,
                         завершение экспедиции
  decode-living-constellation
                       → требует активного Навигатора,
                         +56 pilot XP, +40 pet bond, +3 echo-thread,
                         завершение экспедиции

uncharted-verge-v1 (additive chapter-1-v12 choices)
  ignite-constellation-gate
                       → требует активную Искру-звездочёта stage 2,
                         +54 pilot XP, +52 pet bond, +2 ion-bloom,
                         переход к constellation-sanctuary
  root-constellation-gate
                       → требует активного Мха-оплота stage 2,
                         +70 pilot XP, +40 pet bond, +2 ash-seed,
                         переход к constellation-sanctuary
  read-constellation-gate
                       → требует активного Навигатора созвездий stage 2,
                         +62 pilot XP, +46 pet bond, +2 echo-thread,
                         переход к constellation-sanctuary

constellation-sanctuary-v1 (chapter-1-v12)
  anchor-constellation-sanctuary
                       → +82 pilot XP, +44 pet bond, +3 prism-dust,
                         завершение экспедиции
  carry-sanctuary-song → +68 pilot XP, +60 pet bond, +3 dawn-fragment,
                         завершение экспедиции

constellation-sanctuary-v1 (additive chapter-1-v13 choice)
  decode-sanctuary-signal
                       → требует открытый навык signal-reader,
                         +96 pilot XP, +50 pet bond, +4 echo-thread,
                         завершение экспедиции в v13,
                         переход к hidden-signal-observatory в v14

hidden-signal-observatory-v1 (chapter-1-v14)
  chart-hidden-sector  → +112 pilot XP, +54 pet bond, +4 prism-dust,
                         завершение экспедиции
  preserve-echo-key    → +86 pilot XP, +76 pet bond, +5 echo-thread,
                         завершение экспедиции

hidden-signal-observatory-v1 (additive chapter-1-v15 choice)
  reconstruct-forgotten-route
                       → требует открытый навык trail-memory,
                         +104 pilot XP, +64 pet bond, +3 dawn-fragment,
                         переход к memory-constellation

memory-constellation-v1 (chapter-1-v15)
  archive-return-path  → +120 pilot XP, +58 pet bond, +4 ion-bloom,
                         завершение экспедиции
  entrust-memory-to-pet
                       → +92 pilot XP, +82 pet bond, +6 echo-thread,
                         завершение экспедиции

memory-constellation-v1 (additive chapter-1-v16 choice)
  stabilize-dawn-current
                       → требует открытый навык energy-discipline,
                         +112 pilot XP, +70 pet bond, +3 ion-bloom,
                         переход к dawn-meridian

dawn-meridian-v1 (chapter-1-v16)
  anchor-dawn-flow     → +132 pilot XP, +64 pet bond, +5 dawn-fragment,
                         завершение экспедиции
  share-dawn-flow-with-pet
                       → +100 pilot XP, +90 pet bond, +7 echo-thread,
                         завершение экспедиции

dawn-meridian-v1 (additive chapter-1-v17 choice)
  cross-first-light-causeway
                       → требует открытый навык steady-step,
                         +118 pilot XP, +76 pet bond, +4 prism-dust,
                         переход к first-light-causeway

first-light-causeway-v1 (chapter-1-v17)
  map-first-light-pulse
                       → +144 pilot XP, +72 pet bond, +6 ion-bloom,
                         завершение экспедиции
  follow-pets-steady-pace
                       → +110 pilot XP, +100 pet bond, +8 echo-thread,
                         завершение экспедиции
```

До cluster-wide активации `chapter-1-v2` bootstrap/home/advance/event responses
остаются на `chapter-1-v1`, а `follow-resonance` отсутствует и в `choices`, и в
`lockedChoices`. Прямая новая resolution-команда с этим choice отклоняется.
Exact replay уже сохранённого результата выполняется до проверки release gate.
V1-v12 не проецируют и не принимают `decode-sanctuary-signal`; active v13
проверяет `signal-reader` по authoritative platform state до любой награды или
expedition mutation и завершает journey. Active v14 выполняет ту же проверку,
но продолжает journey в `hidden-signal-observatory`; v1-v13 не могут начать
новый маршрут. Active v15 дополнительно проверяет `trail-memory` перед
переходом в `memory-constellation`; v1-v14 не принимают новый choice ID.
Active v16 проверяет `energy-discipline` перед переходом в `dawn-meridian`;
v1-v15 сохраняют два terminal outcome Созвездия памяти и не принимают новый
choice ID. Active v17 проверяет `steady-step` перед переходом в
`first-light-causeway`; v1-v16 сохраняют два terminal outcome Меридиана
рассвета и не принимают новый choice ID.

Response второго события:

```json
{
  "receiptId": "22222222-2222-2222-2222-222222222222",
  "contentVersion": "chapter-1-v2",
  "expeditionId": "starter-expedition-v1",
  "expeditionStatus": "IN_PROGRESS",
  "expeditionVersion": 4,
  "eventId": "echo-vault-v1",
  "eventTitle": "Хранилище эха",
  "status": "RESOLVED",
  "choiceId": "stabilize-core",
  "choiceTitle": "Стабилизировать ядро",
  "outcomeTitle": "Стабильный резонанс",
  "outcomeSummary": "Ядро перестало разрушаться, а два люминовых осколка сохранили его энергию.",
  "pilot": {
    "pilotId": "navigator-v1",
    "name": "Навигатор",
    "level": 1,
    "experienceGained": 30,
    "currentExperience": 90,
    "nextLevelExperience": 100,
    "version": 2
  },
  "pet": {
    "petId": "spark-v1",
    "name": "Искра",
    "level": 1,
    "bondGained": 8,
    "bond": 23,
    "version": 2
  },
  "material": {
    "itemId": "lumen-shard",
    "name": "Люминовый осколок",
    "description": "Стабильный фрагмент светового ядра, пригодный для будущих улучшений.",
    "quantityGained": 2,
    "quantityAfter": 2,
    "version": 1
  },
  "handoffRequired": true,
  "nextNode": {
    "nodeId": "ash-orbit",
    "name": "Пепельная орбита"
  },
  "serverTime": "2026-07-26T07:00:00Z"
}
```

Для первого события `material = null`. Первое и второе события возвращают
`expeditionStatus = IN_PROGRESS`, потому что открывают следующий узел.
Финальное событие главы возвращает `nextNode = null` и
`expeditionStatus = COMPLETED`.

Для нового, ещё не обработанного resolution `serverTime` фиксируется после
общего user+expedition lock. Pilot/pet progression, material stack/ledger,
expedition transition и durable result используют одно post-lock значение,
поэтому ожидавший lock resolution не может быть датирован раньше уже
завершённой serialized mutation той же экспедиции. Exact replay возвращает
исходный `serverTime` без повторной награды или transition.

Правила:

- event должен быть фактически открыт и expedition должна иметь `EVENT_READY`;
- durable handoff включается только сочетанием capability
  `X-Walking-RPG-Capabilities: durable-event-result-v1` и cluster gate
  `DURABLE_EVENT_RESULT_HANDOFF_ENABLED=true`; response явно возвращает
  сохранённый `handoffRequired`;
- без capability или при выключенном gate backend сохраняет legacy delivery с
  `handoffRequired = false`, auto-ACK и без pending/gameplay gate; это позволяет
  старому mobile продолжить работу;
- новый resolution возвращает
  `409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED`, если у пользователя уже есть
  неподтверждённый capable result receipt той же экспедиции;
- account-deletion subject lock и active check предшествуют expedition lock,
  replay lookup и всем reward/progression mutations в той же транзакции;
- `choiceId` выбирается из server-owned definition соответствующего `eventId`;
- gated choice повторно проверяет authoritative equipment, active pet или
  unlocked pilot skill под
  тем же expedition lock; доступный вариант находится в `choices`, недоступный
  — в additive `lockedChoices`. Home availability используется только для UX,
  а прямой вызов без prerequisite возвращает
  `409 EVENT_CHOICE_UNAVAILABLE`. Equipment requirement содержит
  `minimumUpgradeLevel`/`requiredUpgradeLevel` (legacy default — `1`);
  active-pet requirement использует `type=ACTIVE_PET`, `slotId=ACTIVE_PET`,
  `itemId=<petId>`, `itemName=<petName>` и additive
  `minimumEvolutionStage` (legacy default — `0`), а error details возвращает
  `requirementType=ACTIVE_PET`, `requiredPetId`, `requiredEvolutionStage` и
  `actualEvolutionStage`. Skill requirement использует
  `type=UNLOCKED_SKILL`, `slotId=PILOT_SKILL`, `itemId=<skillId>`; прямой
  вызов без навыка возвращает `requirementType=UNLOCKED_SKILL` и
  `requiredSkillId`;
- `receiptId`, immutable reward snapshot и `nextNode` сохраняются в той же
  транзакции, что и progression/inventory/expedition transition;
- первый event resolution переводит progress на второй узел, второй — на
  третий; только финальное событие главы возвращает `COMPLETED`;
- тот же key и payload возвращает исходный response с тем же `receiptId`,
  `handoffRequired` и `nextNode` без второй награды; capabilities повторного
  запроса не меняют delivery mode;
- тот же key с другим choice возвращает `409 IDEMPOTENCY_CONFLICT`;
- неизвестный choice возвращает `400 VALIDATION_ERROR`;
- после ACK повторное resolution новым key возвращает
  `409 EVENT_STATE_CONFLICT`;
- один inventory source не может выдать другой item или quantity;
- expedition transition/completion, pilot XP, pet bond, inventory stack/ledger
  и processed response фиксируются одной транзакцией;
- pet reward получает активный питомец из authoritative platform state; его
  progress хранится отдельно от других питомцев.

## `POST /api/v1/event-results/{receiptId}/acknowledge`

Подтверждает, что authenticated пользователь увидел durable результат события
и готов продолжить экспедицию.

```http
Authorization: Bearer <access-token>
Accept: application/json
```

```json
{
  "receiptId": "22222222-2222-2222-2222-222222222222",
  "eventId": "echo-vault-v1",
  "status": "ACKNOWLEDGED",
  "acknowledgedAt": "2026-07-26T07:01:00Z",
  "serverTime": "2026-07-26T07:01:00Z"
}
```

Правила:

- request не содержит body; `receiptId` является единственным server-side
  idempotency scope;
- `receiptId` должен быть полным UUID; malformed и сокращённые UUID возвращают
  `400 VALIDATION_ERROR` с `details.field = receiptId` до receipt lookup;
- receipt доступен только своему authenticated user; неизвестный или чужой
  receipt возвращает `404 EVENT_RESULT_NOT_FOUND` без раскрытия владельца;
- повторное acknowledgement того же receipt возвращает стабильные
  `acknowledgedAt` и `serverTime` и не выполняет вторую мутацию;
- acknowledgement захватывает account-deletion subject lock внутри своей
  транзакции до receipt lookup/update, поэтому concurrent deletion не может
  превратить stale command в частичный ACK или другой доменный ответ;
- для новой мутации `serverTime` фиксируется после этого lock и становится
  единым `acknowledgedAt` для receipt и временем ACK milestone; replay
  возвращает сохранённое post-lock время независимо от текущих часов;
- после успешного acknowledgement mobile перечитывает authoritative
  `GET /home`;
- acknowledgement не начисляет награды и не меняет expedition/progression или
  inventory;
- mobile сохраняет receipt в durable GAMEPLAY outbox до первой сетевой попытки
  и replay-ит тот же URL после restart; локальный command key не является
  частью HTTP-контракта.

Flyway V10 присваивает legacy resolutions `receiptId`, но сразу заполняет им
`acknowledgedAt = serverTime`: результаты, уже показанные до появления этого
контракта, не всплывают повторно после upgrade. Колонка
`handoff_required = false` и `BEFORE INSERT` trigger auto-acknowledge также
сохраняют совместимость старого backend writer после применения V10. Partial
unique index ограничивает только строки с `handoff_required = true` и
`acknowledged_at IS NULL`.

Новый mobile принимает legacy response старого backend без `receiptId`,
`handoffRequired` и `nextNode` как немедленно доставленный результат. До
активации gate backend и mobile можно обновлять в любом порядке. Gate
включается только после полного drain старых backend instances; старый binary
нельзя возвращать в mixed pool после активации. Для rollback gate сначала
выключается на всём новом пуле, затем число
`handoff_required AND acknowledged_at IS NULL` доводится до нуля.

В mixed-device сценарии pending receipt, созданный capable-клиентом, остаётся
каноническим и блокирует старый клиент того же аккаунта до ACK; такой клиент
нужно обновить либо подтвердить результат на capable-устройстве.

## `POST /api/v1/crafting/recipes/{recipeId}/craft`

Атомарно расходует server-owned ingredients и создаёт один persistent unique
item. Starter recipe:

```text
resonance-compass-v1
  2 × lumen-shard + 1 × echo-thread
  → 1 × resonance-compass (UNIQUE)
```

```http
Authorization: Bearer <access-token>
Content-Type: application/json
```

```json
{
  "idempotencyKey": "craft-resonance-compass-1"
}
```

```json
{
  "contentVersion": "crafting-v1",
  "recipeId": "resonance-compass-v1",
  "recipeVersion": "1",
  "recipeName": "Собрать резонансный компас",
  "consumedIngredients": [
    {
      "itemId": "echo-thread",
      "name": "Нить эха",
      "quantityConsumed": 1,
      "quantityAfter": 0,
      "version": 2
    },
    {
      "itemId": "lumen-shard",
      "name": "Люминовый осколок",
      "quantityConsumed": 2,
      "quantityAfter": 1,
      "version": 3
    }
  ],
  "craftedItem": {
    "itemInstanceId": "11111111-2222-3333-4444-555555555555",
    "itemId": "resonance-compass",
    "name": "Резонансный компас",
    "description": "Уникальный прибор, собранный из люминовых осколков и нити эха.",
    "version": 1,
    "craftedAt": "2026-08-01T08:00:00Z"
  },
  "serverTime": "2026-08-01T08:00:00Z"
}
```

Правила:

- request не принимает quantity, result item или reward от клиента;
- account-deletion lock с active-subject check удерживается до commit;
- следующий user-scoped transaction lock сериализует competing craft-команды;
- material rows блокируются в стабильном `itemId`-порядке;
- проверка всех ingredients предшествует списанию; shortage откатывает всю
  транзакцию и возвращает `409 INSUFFICIENT_MATERIALS` с required/available;
- каждое списание имеет отрицательный `inventory_ledger.quantityDelta`, при
  этом `quantityAfter >= 0` и delta не может быть нулевой;
- unique item ограничен одной строкой на `user + itemId` и `user + recipeId`;
- exact replay исходного `user + recipeId + idempotencyKey` возвращает тот же
  item instance, ingredient snapshots и timestamps без новой мутации;
- exact replay остаётся доступен при pending event receipt, но новая
  craft-команда сериализуется с advance/event resolution и возвращает
  `409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED` до material debit;
- новый key после уже созданного result возвращает
  `409 CRAFT_ALREADY_COMPLETED`;
- неизвестный recipe возвращает `404 CRAFTING_RECIPE_NOT_FOUND`;
- mobile хранит `recipeId`/key в GAMEPLAY outbox и после успеха перечитывает
  authoritative `GET /home`.

## `POST /api/v1/item-upgrades/{upgradeId}/apply`

Атомарно применяет server-owned улучшение к существующему unique item. В
`item-upgrade-v1` definition `prism-sextant-calibration-v1` доступен только с
active `chapter-1-v5`:

```text
2 × echo-thread + 1 × prism-dust + 1 × ion-bloom
→ тот же prism-sextant: 1/UNCOMMON → 2/RARE
```

Начиная с active `chapter-1-v8` дополнительно открывается definition
`prism-sextant-second-dawn-attunement-v1` из `item-upgrade-v2`:

```text
2 × echo-thread + 2 × ion-bloom + 2 × dawn-fragment
→ тот же prism-sextant: 2/RARE → 3/EPIC
```

V1-V7 не проецируют и не принимают новый upgrade; v9 сохраняет его доступность.
Home возвращает определения
в порядке `calibration → attunement`, поэтому завершённый первый шаг остаётся
виден рядом со следующей постоянной целью.

```json
{
  "idempotencyKey": "upgrade-prism-sextant-1"
}
```

```json
{
  "contentVersion": "item-upgrade-v1",
  "upgradeId": "prism-sextant-calibration-v1",
  "upgradeVersion": "1",
  "upgradeName": "Откалибровать призматический секстант",
  "consumedIngredients": [
    {
      "itemId": "echo-thread",
      "name": "Нить эха",
      "quantityConsumed": 2,
      "quantityAfter": 0,
      "version": 2
    }
  ],
  "upgradedItem": {
    "itemInstanceId": "11111111-2222-3333-4444-555555555555",
    "itemId": "prism-sextant",
    "name": "Призматический секстант",
    "description": "Уникальный навигационный прибор.",
    "previousLevel": 1,
    "upgradeLevel": 2,
    "rarity": "RARE",
    "upgradedAt": "2026-08-15T08:00:00Z"
  },
  "serverTime": "2026-08-15T08:00:00Z"
}
```

Правила:

- request не принимает item instance, стоимость, level или rarity;
- user/crafting lock и общий expedition lock сериализуют command с crafting,
  equipment, advance/resolution и account deletion;
- target row и все material rows блокируются; shortages возвращают
  `409 INSUFFICIENT_MATERIALS` без частичной мутации;
- exact replay возвращает исходный item/ingredient/timestamp snapshot до
  content и pending-result gates;
- отсутствующий, несовместимый или уже улучшенный target возвращает
  `409 ITEM_UPGRADE_STATE_CONFLICT` с stable `details.reason`;
- неизвестный/inactive upgrade возвращает `404 ITEM_UPGRADE_NOT_FOUND`;
- mobile хранит `upgradeId`/key как `ITEM_UPGRADE` в GAMEPLAY outbox и после
  успеха перечитывает authoritative `GET /home`.

## Equipment

### `POST /api/v1/equipment/slots/{slotId}/equip`

Экипирует принадлежащий authenticated пользователю unique item в server-owned
slot. В `equipment-v1` поддержан `slotId=NAVIGATION`, а допустимый item —
`resonance-compass`.

```json
{
  "itemInstanceId": "11111111-2222-3333-4444-555555555555",
  "idempotencyKey": "equip-compass-1"
}
```

```json
{
  "contentVersion": "equipment-v1",
  "slotId": "NAVIGATION",
  "slotName": "Навигационный прибор",
  "slotDescription": "Один уникальный инструмент, влияющий на доступные маршруты.",
  "action": "EQUIP",
  "changed": true,
  "version": 1,
  "equippedItem": {
    "itemInstanceId": "11111111-2222-3333-4444-555555555555",
    "itemId": "resonance-compass",
    "name": "Резонансный компас",
    "description": "Уникальный прибор, собранный из люминовых осколков и нити эха.",
    "equippedAt": "2026-08-01T08:05:00Z"
  },
  "serverTime": "2026-08-01T08:05:00Z"
}
```

### `POST /api/v1/equipment/slots/{slotId}/unequip`

Снимает предмет. Request содержит только key; `itemInstanceId` запрещён.
Response имеет `action=UNEQUIP`, `equippedItem=null` и authoritative slot
version.

```json
{
  "idempotencyKey": "unequip-compass-1"
}
```

Правила:

- `itemInstanceId` должен быть полным UUID; malformed и сокращённые UUID
  возвращают `400 VALIDATION_ERROR` с `details.field = itemInstanceId` до
  equipment service и persistent locks;
- slot/item compatibility и ownership проверяет backend; чужой или
  отсутствующий instance возвращает `409 EQUIPMENT_ITEM_UNAVAILABLE` без
  раскрытия владельца;
- composite database FK не позволяет связать slot с item другого user;
- account-deletion lock предшествует equipment lock и replay lookup;
- exact replay выполняется до pending-result guard и возвращает исходный
  response; тот же key с другим action/item возвращает
  `409 IDEMPOTENCY_CONFLICT`;
- новая команда сериализуется с advance/event resolution/crafting и при
  pending receipt возвращает `409 EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED`;
- повтор уже достигнутого desired state с новым key возвращает
  `changed=false` без увеличения version;
- mobile хранит `EQUIPMENT` в GAMEPLAY outbox и принимает новый slot state
  только после authoritative `GET /home`.

## `GET /api/v1/platform`

Возвращает versioned platform snapshot: onboarding, три питомца, навыки,
задания, достижения, сезон, недельный маршрут, отряд, косметику, эксперименты и
remote config. Канонический первый путь содержит шесть шагов:

```json
[
  "welcome",
  "health-permission",
  "first-sync",
  "pet-selection",
  "first-expedition",
  "first-event"
]
```

`activePetId` согласован с единственным `pets[].active=true`. Каждый питомец
содержит `trait`, независимые `level/bond/evolutionStage` и server-owned
`evolutionBond` для следующего перехода. Additive
`maximumEvolutionStage` задаёт последнюю доступную форму: v1-v10 возвращают
`1`, а `chapter-1-v11` и новее — `2`. Если сохранённая стадия выше лимита
активного контента после rollback, projection возвращает сохранённую стадию
как effective maximum, но новая эволюция остаётся запрещена правилами
активного контента. Mobile при отсутствии поля использует `1`, поэтому новый
клиент со старым backend и старый клиент с новым backend не показывают
недоступную вторую команду. На v11+ переходы разрешены только
`0 → 1` и `1 → 2`; thresholds равны `50/140` для Spark, `45/125` для Moss и
`55/150` для `rune-v1` («Навигатор»).
`userState.hasSuccessfulActivitySync` — долговечный
authoritative fact наличия хотя бы одной успешно обработанной activity-команды,
включая sync с нулём шагов; он не сбрасывается при смене локальной даты или
очистке идемпотентных activity-receipts по retention policy и не выводится из
push-регистрации устройства.

`userState.equippedCosmetics` — additive object `slot -> cosmeticId`, например
`{"PILOT":"pilot-scarf","PET":"spark-halo"}`. В одном server-owned слоте
может быть только один принадлежащий пользователю cosmetic; разные слоты
экипируются одновременно. `activeCosmeticId` временно сохраняется как указатель
на последний выбранный предмет для старых клиентов. Во время rolling upgrade
поле может отсутствовать в exact replay ответа, записанного до V17; следующий
`GET /api/v1/platform` возвращает актуальную per-slot projection.

Все user state, progress facts, squad, content и remote config в одном response
читаются из единого `REPEATABLE_READ` snapshot. Параллельный activity sync или
admin publish, завершившийся после фиксации snapshot, целиком попадает только в
следующий platform response. `serverTime` для platform snapshot и content
bootstrap возвращается первым PostgreSQL `statement_timestamp()` и относится
к границе именно этого snapshot; поздняя блокировка остальных секций не
сдвигает метку к времени завершения response.

Mutable runtime values не имеют второго источника истины внутри content
projection: `content.season.seasonId` равен `remoteConfig.seasonId`, а
`content.weeklyRoute.requiredEnergy` и
`userState.weeklyRouteRequiredEnergy` равны
`remoteConfig.weeklyRouteEnergy`. `GET /api/v1/platform` и
`GET /api/v1/content/bootstrap` строят catalog и remote config из одного
effective config snapshot, поэтому clean install и последующая admin-публикация
не могут выдать противоречащие друг другу значения.

Mobile рассматривает display copy current Platform catalog как mutable
presentation: шесть известных onboarding step IDs, четыре skill IDs, пять
quest IDs, восемь achievement IDs, четыре cosmetic IDs, текущий season ID и
два experiment IDs разрешаются через generated RU/EN resources только по
stable identity. Unknown ID сохраняет literal server value. Squad name и ID
остаются пользовательскими literal values, а decision log, completion recap,
archive и их reward names остаются immutable persisted copy и не переводятся
повторно при смене locale.

Account/recovery/activity/Validation Center и shared mobile boundaries также
являются client presentation и не расширяют API schema: стабильные
command/error categories отображаются через generated RU/EN resources. Raw
backend/runtime message не становится player copy. Возвращённые API filename,
receipt ID, timestamp, evidence wire value и server-owned ID остаются literal
facts; смена locale их не переписывает и не влияет на idempotency, persisted
history или evidence checksum.

## Admin-публикация platform config и content

`PUT /api/v1/admin/platform/remote-config` и
`POST /api/v1/admin/platform/content-releases` сохраняют single-active
семантику при конкурентных запросах с разных backend instances. Каждый поток
публикации получает отдельный bounded transaction-scoped PostgreSQL lock до
деактивации текущей строки. Поэтому remote config не блокирует независимый
content release, а два издателя одного типа завершаются последовательно:
последняя закоммиченная версия остаётся единственной активной вместо ответа
`500` из-за гонки partial unique index. `createdAt` фиксируется после получения
lock и отражает фактический порядок публикации.

`version` remote config и `contentVersion` content release нормализуются через
trim до lock и записи. Immediate response возвращает тот же canonical identifier,
который хранится в active row и появится в последующем authoritative read;
граничный whitespace не может создать два представления одной публикации.

`activityRetentionDays` и `weeklyRouteEnergy` принимают только точные целые
JSON-числа в своих допустимых диапазонах. Дробные значения отклоняются до
publication lock и не меняют активный snapshot.
Допустимая decimal-запись целого числа канонизируется в JSON integer, а
`seasonId` trim-ится до того же lock. Canonical config используется для записи,
immediate admin response и последующего public bootstrap, поэтому `30.0` и
`"  season-1  "` не создают разные представления одного active snapshot.

`POST /api/v1/admin/platform/content-releases` требует явно присутствующий
непустой JSON object `content`. Missing, `null` и `{}` возвращают
`400 VALIDATION_ERROR` с полем `content` до application service и publication
lock; непустой content сохраняет прежний `201` response contract.

## `POST /api/v1/platform/commands`

Все platform mutations используют одну restart-safe командную ручку:

```json
{
  "commandType": "SELECT_PET",
  "idempotencyKey": "first-journey-select-moss-v1",
  "payload": {
    "petId": "moss-v1"
  }
}
```

Успешный response сохраняет `commandType` и server-authored `message` для
совместимости. Mobile показывает локализованный player feedback по известному
stable `commandType`; unknown future command сохраняет literal `message`.
Ошибка команды показывается как локализованное fail-closed состояние без
вывода server diagnostic message в player-facing English copy.

`payload` обязан явно присутствовать как JSON object. Missing/null возвращает
`400 VALIDATION_ERROR` до application service, изменения platform state и
durable idempotency receipt. Явный `{}` остаётся допустимым для команд без
собственных полей, включая `LEAVE_SQUAD`.

Новая команда принимает только точный набор полей своего `commandType`.
Неожиданные ключи возвращают `400 VALIDATION_ERROR` с полем `payload` до чтения
runtime publications, provider call, platform state или telemetry event. Это
не позволяет проигнорированному client field менять durable fingerprint той же
business-команды; для `RECORD_COMPASS_IMPRESSION` клиент, в частности, не может
передать `eventId`, `choiceId` или timestamp. Lookup уже сохранённого receipt
выполняется раньше этой проверки, поэтому exact replay исторической команды,
которая была принята старым binary с лишним полем, остаётся доступен без новой
мутации.

Числовые поля payload имеют строгую целочисленную семантику. Значения с
ненулевой дробной частью не усекаются и возвращают `400 VALIDATION_ERROR` с
именем поля; это относится, в частности, к `energyToSpend` и `level`.

После user-scoped serialization новая, ещё не обработанная команда читает
effective remote config и active content version ровно по одному разу. Эти
snapshot-ы используются для provider/feature gate, `weeklyRouteEnergy`, derived
achievements, проверки route impression и всех `content/userState/remoteConfig`
секций response. Если admin-публикация завершилась, пока команда ожидала
downstream lock, in-flight команда завершается целиком на исходных runtime
публикациях, а следующая команда или read endpoint уже видит новые. Durable
response не может принять impression для одной content version и сохранить
catalog другой версии. `serverTime` новой команды фиксируется после этих
runtime reads: принятый route impression и его analytics event не могут быть
датированы раньше content activation, которую они уже наблюдали. Exact replay
по-прежнему возвращает сохранённую
business-проекцию; текущая доступность deployment provider может только
fail-closed заменить capability field на `false` без повторной мутации.
Сохранённое `sandboxPaymentsEnabled=false` не становится `true`, даже если более
поздняя admin-публикация и текущий provider уже разрешают sandbox payments.

Правила первого пути:

- `SELECT_PET` атомарно меняет `activePetId` и отмечает `pet-selection`;
- выбор уже активного питомца всё равно завершает milestone, если он ещё не
  был сохранён;
- `CLAIM_QUEST` и `EVOLVE_PET` обновляют platform state и соответствующую
  `pet_progress` строку одной транзакцией;
- `EVOLVE_PET` проверяет threshold следующей стадии и content-version maximum;
  v1-v10 остаются на стадии `1`, а v11+ разрешают взрослую стадию `2`;
- `COMPLETE_ONBOARDING_STEP` записывается после соответствующего реального
  действия; mobile не показывает отдельные кнопки фиктивного завершения;
- после process restart mobile восстанавливает `health-permission`,
  `first-sync`, `first-expedition` и `first-event` из authoritative facts;
  activity-факт берётся из `hasSuccessfulActivitySync`, а не из положительного
  количества шагов, после чего mobile идемпотентно backfill-ит отсутствующие
  служебные milestones;
- активный питомец затем возвращается в `GET /home` и получает event bond.
- `CREATE_SQUAD`, `JOIN_SQUAD`, `LEAVE_SQUAD` и удаление аккаунта владельца
  сериализуются общим transaction-scoped lock по `squadId`; параллельный выход
  владельца и последнего участника либо удаляет пустой отряд, либо передаёт
  владение участнику, который остаётся в нём. Для новой squad-команды
  `serverTime` фиксируется после этого lock и одним значением датирует
  membership, platform state, audit event и durable response. Exact replay
  возвращает сохранённое post-lock время без повторного получения squad lock.
- `JOIN_SQUAD.payload.squadId` должен быть полным UUID. Canonical UUID с
  буквами в верхнем регистре нормализуется перед state/DB mutation; malformed и
  укороченные формы возвращают `400 VALIDATION_ERROR` с полем `squadId` до
  создания platform state или получения squad lock.
- `BUY_COSMETIC` остаётся совместимым alias для `PURCHASE_COSMETIC`, но до
  fingerprint lookup оба имени сводятся к одному canonical command scope.
  Повтор с тем же key через другой alias возвращает immutable первый response,
  а другой `cosmeticId` получает `409 IDEMPOTENCY_CONFLICT` до provider call или
  изменения состояния. Новая покупка в одной транзакции сохраняет одинаковый
  response под canonical и legacy scopes с соответствующими fingerprints, чтобы
  экземпляр предыдущей версии во время rolling deployment также выполнил exact
  replay. Старые processed rows с `command_type=BUY_COSMETIC` продолжают exact
  replay через отдельный legacy lookup.
- `EQUIP_COSMETIC` принимает только `cosmeticId`: slot выводится из server
  catalog. Команда материализует прежний `activeCosmeticId`, заменяет только
  соответствующий `PILOT`/`PET`/`PROFILE` slot и сохраняет остальные slots;
  неизвестный или не принадлежащий пользователю item отклоняется до изменения.
- Fingerprint `payload` канонизирует порядок ключей рекурсивно: одинаковые JSON
  objects replay-ятся независимо от порядка полей после restart/между backend
  instances. Выделенный immutable writer не наследует pretty-print и другие
  настройки общего API `ObjectMapper`, поэтому форматирование response между
  deployment-ами не превращает exact replay в конфликт. Порядок arrays,
  значения и JSON-типы остаются значимыми. Для сохранённых до канонизации
  двухполевых compass/exposure payload backend принимает оба прежних top-level
  порядка. Replay-only compatibility также принимает bounded compact/indented
  hashes непосредственно предыдущего shared API mapper; новые rows их не
  сохраняют. Другой business payload по-прежнему получает
  `409 IDEMPOTENCY_CONFLICT` до любой записи.

### `commandType=RECORD_COMPASS_IMPRESSION`

Authenticated mobile регистрирует показ compass UX через существующий
`POST /api/v1/platform/commands`. Команда является cache-neutral telemetry:
она не меняет `stateVersion`, не инвалидирует Home/Platform cache и exact
replay возвращает исходный response без второй записи события. Backend не
запускает для неё reconciliation и не сохраняет новые progress facts в
`roadmap_user_state`; snapshot ответа остаётся на сохранённой версии state.

```json
{
  "commandType": "RECORD_COMPASS_IMPRESSION",
  "idempotencyKey": "compass-impression-chapter-1-v2-route-mirror-delta-v1-follow-resonance-ROUTE_AVAILABLE",
  "payload": {
    "impression": "ROUTE_AVAILABLE",
    "contentVersion": "chapter-1-v2"
  }
}
```

Client передаёт только enum показа и версию фактически полученного network
Home. Backend записывает server receive time и сам подставляет stable content
IDs; произвольные `recipeId`, `eventId`, `choiceId`, availability или timestamp
не принимаются.

| `impression` | Canonical event | Canonical attributes |
|---|---|---|
| `RECIPE_MISSING_MATERIALS` | `compass_recipe_impression` | `recipeId=resonance-compass-v1`, `status=MISSING_MATERIALS` |
| `RECIPE_READY` | `compass_recipe_impression` | `recipeId=resonance-compass-v1`, `status=READY` |
| `RECIPE_CRAFTED` | `compass_recipe_impression` | `recipeId=resonance-compass-v1`, `status=CRAFTED` |
| `ROUTE_LOCKED` | `compass_route_impression` | `eventId=mirror-delta-v1`, `choiceId=follow-resonance`, `availability=LOCKED` |
| `ROUTE_AVAILABLE` | `compass_route_impression` | `eventId=mirror-delta-v1`, `choiceId=follow-resonance`, `availability=AVAILABLE` |

Оба event содержат `contractVersion=compass-beta-funnel-v1` и переданный
из network snapshot `contentVersion`. Route impressions допустимы только для
`chapter-1-v2`, когда эта версия уже активна в `content_release`; exact replay
проверяется раньше release gate. Cached Home не отправляет impression; network
snapshot отправляет его только после viewport exposure соответствующей card при
текущей Home route и foreground app.

## `GET /api/v1/admin/platform/analytics/retention`

Admin-only агрегированный D1/D7/D30 read model. Cohort day определяется по
UTC-дате `app_user.created_at`. Activity arm использует сохранённую локальную
дату успешной activity state, а telemetry arm — UTC-дату server-owned
`platform_event.received_at`. Client-controlled `occurredAt` сохраняется для
диагностики, но не может переместить пользователя в другой retention day.
Telemetry day проверяется полуинтервалом `[UTC day start, next UTC day start)`,
который использует V16 index `(user_id, received_at)` без преобразования
индексируемой колонки к `date`.
Для каждого Dn `eligibleUsers` включает только пользователей, у которых к
единому `generatedAt` полностью завершился соответствующий целевой UTC-день.
Недавно созданные аккаунты с ещё не наблюдённым или частично наблюдённым днём
не уменьшают rate; `cohortSize` по-прежнему показывает все текущие аккаунты.
Все cohort/day/onboarding counters одного ответа читаются в одной
`REPEATABLE_READ` транзакции и не смешивают состояния до и после конкурентной
записи. `cohortSize` и PostgreSQL `statement_timestamp()` читаются одним первым
statement; возвращаемый `generatedAt` является временем фиксации snapshot, а
не временем начала handler или завершения последней секции.

```json
{
  "cohortSize": 40,
  "generatedAt": "2026-08-06T12:00:00Z",
  "d1": {"day": 1, "eligibleUsers": 30, "retainedUsers": 24, "rate": 0.8},
  "d7": {"day": 7, "eligibleUsers": 20, "retainedUsers": 14, "rate": 0.7},
  "d30": {"day": 30, "eligibleUsers": 10, "retainedUsers": 8, "rate": 0.8},
  "onboarding": {"startedUsers": 32, "completedUsers": 19}
}
```

Значения являются cumulative cohort summary текущей базы и не заменяют
датированное beta evidence с зафиксированными cohort/build/периодом.

## `GET /api/v1/admin/platform/analytics/first-journey`

Admin-only read model первого пути. Опциональный `cohortCode` ограничивает
выборку участниками `tester_cohort_member`.

```json
{
  "cohortCode": "alpha-1",
  "eligibleUsers": 12,
  "startedUsers": 10,
  "notStartedUsers": 2,
  "startRate": 0.8333333333333334,
  "stages": [
    {
      "milestone": "FIRST_ENERGY",
      "reachedUsers": 8,
      "missingFromStartedUsers": 2,
      "authoritativeReachedUsers": 8,
      "timedUsers": 8,
      "conversionFromStarted": 0.8,
      "authoritativeConversionFromStarted": 0.8,
      "medianSecondsFromStart": 45,
      "p90SecondsFromStart": 90
    }
  ],
  "dataQuality": {
    "authoritativeMilestoneRecords": 58,
    "backfilledMilestoneRecords": 7
  },
  "generatedAt": "2026-07-29T17:00:00Z"
}
```

`eligibleUsers` и `generatedAt` читаются одним первым PostgreSQL statement.
Поэтому метка относится к тому же `REPEATABLE_READ` snapshot, что funnel и
data-quality counters, даже если одна из последующих секций ждёт lock.

`reachedUsers` и `conversionFromStarted` допускают migration/compatibility
backfill ради continuity coverage. `authoritativeReachedUsers` и
`authoritativeConversionFromStarted` показывают долю без такого inference.
Latency percentiles используют только пары
`JOURNEY_STARTED → milestone`, где обе записи `AUTHORITATIVE` и целевое время
не раньше старта. Поэтому приблизительные legacy timestamps не смешиваются с
alpha timing. Milestones переживают retention `processed_activity_sync`, входят
в account export и удаляются вместе с аккаунтом.

`stages` — расширяемый массив, а каждый stage object допускает additive fields:
consumer должен игнорировать неизвестные поля, находить запись по `milestone`
и не полагаться на фиксированную длину или индекс. Для конца первого пути
различаются три факта:

- `FIRST_EVENT_RESOLVED` — rewards/progression атомарно сохранены;
- `ONBOARDING_COMPLETED` — прежний platform onboarding state и шесть
  server-authoritative фактов завершены;
- `FIRST_EVENT_RESULT_ACKNOWLEDGED` — результат подтверждён через durable
  receipt и является отдельным delivery stage alpha.

Explicit durable ACK имеет `source = AUTHORITATIVE`,
`attributes.handoffRequired = true` и участвует в p50/p90. V10 legacy auto-ACK
и V11 migration backfill имеют `source = BACKFILLED`: они могут участвовать в
continuity `conversionFromStarted`, но исключаются из
`authoritativeConversionFromStarted` и timing. Для explicit alpha ACK rate
используется `authoritativeConversionFromStarted`. Если у state-only legacy
пользователя нет receipt evidence, ACK milestone не синтезируется.

## `GET /api/v1/admin/platform/analytics/compass-journey`

Admin-only агрегированный read model для beta-пути
`recipe → craft → equip → hidden route`. Опциональный `cohortCode` использует
ту же membership-семантику `tester_cohort_member`, что first-journey analytics.
Ответ не содержит user IDs и читается целиком в одной PostgreSQL
`REPEATABLE_READ` транзакции.

```json
{
  "cohortCode": "compass-beta",
  "eligibleUsers": 40,
  "instrumentedUsers": 32,
  "instrumentationRate": 0.8,
  "funnels": [
    {
      "funnel": "CRAFTING_EQUIPMENT",
      "startStage": "RECIPE_SEEN",
      "startSource": "CLIENT_REPORTED",
      "startedUsers": 30,
      "notStartedUsers": 10,
      "startRate": 0.75,
      "stages": [
        {
          "stage": "COMPASS_EQUIPPED",
          "source": "AUTHORITATIVE",
          "reachedUsers": 18,
          "missingFromStartedUsers": 12,
          "orderedUsers": 17,
          "outOfOrderUsers": 1,
          "conversionFromStarted": 0.6,
          "orderedConversionFromStarted": 0.5666666666666667,
          "medianSecondsFromStart": 420,
          "p90SecondsFromStart": 1800
        }
      ]
    }
  ],
  "dataQuality": {
    "clientReportedStageRecords": 55,
    "authoritativeStageRecords": 49,
    "outOfOrderPairs": 3,
    "craftingTargetsWithoutStartUsers": 4,
    "routeTargetsWithoutStartUsers": 2
  },
  "generatedAt": "2026-07-30T18:00:00Z"
}
```

`eligibleUsers` и `generatedAt` читаются одним первым PostgreSQL statement.
Application clock не участвует в метке: поздняя блокировка funnel query не
может датировать уже зафиксированный `REPEATABLE_READ` snapshot временем
завершения ответа.

Состав funnel-ов и источники:

| Funnel | Baseline | Следующие stages |
|---|---|---|
| `CRAFTING_EQUIPMENT` | `RECIPE_SEEN` (`CLIENT_REPORTED`) | `RECIPE_READY_SEEN` (`CLIENT_REPORTED`), `COMPASS_CRAFTED`, `COMPASS_EQUIPPED` (`AUTHORITATIVE`) |
| `RESONANCE_ROUTE` | `MIRROR_DELTA_REACHED` (`AUTHORITATIVE`) | `ROUTE_LOCKED_SEEN`, `ROUTE_AVAILABLE_SEEN` (`CLIENT_REPORTED`), `RESONANCE_ROUTE_CHOSEN`, `RESONANCE_ROUTE_COMPLETED` (`AUTHORITATIVE`) |

`RESONANCE_ROUTE` открывает baseline только при активной `chapter-1-v2`.
Пользователь, ожидавший на Mirror Delta до активации, стартует в
`max(mirrorReachedAt, v2ActivatedAt) = v2ActivatedAt`; достигший событие позже
стартует по receipt. Если Mirror Delta уже resolved до активации, пользователь
не входит в route denominator: legacy choice нельзя переиграть после rollout.
Staged V14 timestamp не считается exposure или началом latency.
Baseline использует V15 `content_release.activated_at`, который заполняется
при первой активации и остаётся immutable при republish; mutable `createdAt`
release row не участвует в timing.

`reachedUsers`/`conversionFromStarted` отвечают на вопрос, встречались ли обе
стадии у пользователя. `orderedUsers` и latency percentiles дополнительно
требуют `target.occurredAt >= baseline.occurredAt`; отрицательная или
legacy/offline пара остаётся видна в `outOfOrderUsers`, но не искажает timing.
Target без baseline не включается в conversion и отражается в соответствующем
`*TargetsWithoutStartUsers`.

`clientReportedStageRecords` и `authoritativeStageRecords` — число первых
user-stage записей после дедупликации, а не число raw event rows. Client
impression доказывает только доставку canonical telemetry command и не
заменяет gameplay truth. Поэтому beta-решения должны указывать cohort/build/
период, проверять `instrumentationRate` и опираться на authoritative stages.

## Anonymous telemetry и diagnostics

Оба endpoint-а нужны для startup/pre-authentication diagnostics и поэтому
принимают anonymous request. Если валидная authentication присутствует,
backend может связать запись с canonical subject; client-controlled `userId`
не принимается.

### `POST /api/v1/telemetry/events`

Raw JSON body ограничен 16 KiB. `eventName` обязателен и не длиннее 100
символов; `attributes` содержит не более 64 top-level keys. Имена
`compass_recipe_impression` и `compass_route_impression` зарезервированы для
server-owned platform command и отклоняются до создания user/event row, чтобы
public ingress не подменял canonical server time/attributes funnel-а.

```json
{
  "eventName": "app_started",
  "occurredAt": "2026-07-30T08:00:00Z",
  "attributes": {
    "source": "cold-start"
  }
}
```

Успех: `202 Accepted`.

```json
{
  "accepted": true
}
```

### `POST /api/v1/diagnostics/crashes`

Raw JSON body ограничен 64 KiB. Ограничения:

- `platform`: 32 символа;
- `appVersion`: 64;
- `errorType`: 160;
- `message`: 2 000;
- `stackTrace`: 32 768;
- `context`: не более 64 top-level keys.

```json
{
  "platform": "android",
  "appVersion": "0.1.0",
  "errorType": "startup_failure",
  "message": "Initialization failed",
  "stackTrace": null,
  "context": {
    "phase": "bootstrap"
  },
  "occurredAt": "2026-07-30T08:00:00Z"
}
```

Успех: `202 Accepted` с `{"accepted":true}`.

Для authenticated telemetry и crash reports server-owned `received_at`
фиксируется только после account-deletion subject lock. То же post-lock время
используется для создаваемого/обновляемого `app_user`; поэтому request,
ожидавший предыдущую account mutation через границу UTC, относится к дню
фактической serialized записи. Переданный клиентом `occurredAt` остаётся
диагностическим временем события и не подменяет `received_at`. Anonymous
ingestion не имеет account boundary и снимает receive time непосредственно
перед записью.

### Abuse responses

Каждый route имеет bounded per-process client и global rate limits. Backend не
доверяет forwarded headers как client identity. Эти limits не являются
distributed WAF/gateway quota.

- oversized raw body: `413 PAYLOAD_TOO_LARGE`;
- исчерпанный client/global bucket: `429 RATE_LIMITED` и `Retry-After`;
- DTO violation: `400 VALIDATION_ERROR`.

Все reject происходят до application service/database write, имеют
`Cache-Control: no-store`. Error envelope не содержит raw body, client key,
remote address, token, crash message или stack trace.

## Operational endpoints

Operational endpoints не являются mobile API:

| Endpoint | Назначение | Доступ |
|---|---|---|
| `GET /livez` | canonical application-port liveness без dependency details | anonymous |
| `GET /readyz` | canonical application-port readiness, включая PostgreSQL | anonymous |
| `GET /actuator/health/liveness` | management-port liveness counterpart | anonymous |
| `GET /actuator/health/readiness` | management-port readiness counterpart | anonymous |
| `GET /actuator/prometheus` | management-port low-cardinality metrics | `ROLE_ADMIN` |

В `stage`/`prod` management listener по умолчанию отделён от application
listener и привязан к `127.0.0.1:8081`; на application listener дополнительно
проецируются только no-detail `/livez` и `/readyz`. Health details/components и
Actuator discovery не публикуются; остальные operational routes запрещены.
Реальный ingress и monitoring path требуют external network evidence.

## Ошибки

Базовый формат:

```json
{
  "code": "VALIDATION_ERROR | PAYLOAD_TOO_LARGE | RATE_LIMITED | NOT_FOUND | CONFLICT | INTERNAL_ERROR",
  "message": "человекочитаемое описание",
  "details": {
    "field": "idempotencyKey"
  },
  "traceId": "uuid"
}
```

Используемые domain code:

```text
IDEMPOTENCY_CONFLICT
INSUFFICIENT_ENERGY
EXPEDITION_STATE_CONFLICT
EVENT_STATE_CONFLICT
EVENT_CHOICE_UNAVAILABLE
EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED
EVENT_RESULT_NOT_FOUND
INSUFFICIENT_MATERIALS
CRAFT_ALREADY_COMPLETED
CRAFTING_RECIPE_NOT_FOUND
EQUIPMENT_ITEM_UNAVAILABLE
EQUIPMENT_SLOT_NOT_FOUND
INVENTORY_LEDGER_CONFLICT
VALIDATION_ERROR
NOT_FOUND
```

## Дополнительный content endpoint

```text
GET  /api/v1/content/bootstrap
```

Вложенный `content.catalogDigest` — SHA-256 канонического содержимого каталога
без самого digest. Порядок ключей JSON object на значение не влияет, порядок
элементов массивов остаётся значимым. Любое изменение server-owned catalog
value, включая `contentVersion`, effective `seasonId` и
`weeklyRouteEnergy`, меняет digest; повторная выдача того же каталога возвращает
то же значение. Расчёт использует отдельный writer с фиксированным порядком
object properties и без форматирования, поэтому настройки API `ObjectMapper`,
включая pretty-print, на digest не влияют.
