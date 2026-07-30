# ADR 0024: Mobile command recovery и изоляция telemetry

- Статус: принято
- Дата: 2026-07-30

## Контекст

Foreground outbox из ADR 0012 сохраняет mutation до сетевой попытки и
повторяет исходный payload с тем же idempotency key после restart. Однако для
alpha этого недостаточно:

- `PENDING` и terminal `FAILED` после первого SnackBar были невидимы;
- пользователь не мог безопасно инициировать повтор без нового business
  action;
- повреждённый store не имел постоянного fail-closed состояния в UI;
- `RECORD_EXPERIMENT_EXPOSURE` находился в `GAMEPLAY` lane, поэтому недоступная
  telemetry могла задержать event-result ACK или другую игровую команду;
- startup replay запускался и в `FirstJourneyGate`, и во вложенном
  `ActivitySyncShell`.

При этом экран поддержки не должен раскрывать payload, idempotency key,
fingerprint, receipt, Health cursor, raw backend error или путь к локальному
файлу.

## Решение

### Три независимые lane

Outbox использует:

```text
ACTIVITY  — ACTIVITY_SYNC
GAMEPLAY  — advance, event resolution, result ACK и изменяющие state
            platform-команды
TELEMETRY — RECORD_EXPERIMENT_EXPOSURE
```

Lane выводится из типа и семантики сохранённого payload. Существующая
`PLATFORM_COMMAND` с `commandType = RECORD_EXPERIMENT_EXPOSURE` автоматически
попадает в `TELEMETRY`, в том числе если была записана старой версией mobile.
Формат файла остаётся v1: отдельная миграция локального store не нужна.

Команды одной lane выполняются FIFO под одним lock. State-changing цепочка
сохраняет порядок `ACTIVITY → GAMEPLAY`: activity sync может зачислить ENERGY,
необходимую следующей gameplay-команде. Если ACTIVITY остаётся `PENDING` после
retryable failure, GAMEPLAY в этом replay вообще не запускается и также
остаётся `PENDING`; terminal activity не удерживает цепочку. `TELEMETRY`
replay-ится параллельно со всей этой цепочкой, поэтому недоступная exposure не
задерживает gameplay или activity. Submit новой exposure-команды сразу берёт
`TELEMETRY` lock, а не статический lock типа `PLATFORM_COMMAND`.
Startup replay ждёт только state-changing цепочку. TELEMETRY
запускается как отдельная close-tracked операция: её timeout не удерживает
первый экран или authoritative reload, а поздний результат публикует change
для recovery badge. Явная кнопка Recovery, напротив, ждёт и показывает итог
всех lane, поэтому повторное нажатие не ставит telemetry retries в очередь.

### Один startup replay

В authenticated application shell владельцем однократного startup replay
остаётся `FirstJourneyGate`. Вложенный `ActivitySyncShell` получает
`replayOnStart = false`. Самостоятельный `ActivitySyncShell` также имеет
безопасный default `false`; явный opt-in требует injected session-owned
runtime. Созданный самим shell runtime используется только для foreground
submit, не запускает startup replay и закрывается вместе со State.

`MobileCommandRuntime` memoize-ит первую startup Future на весь lifetime
authenticated runtime. Первый всё ещё активный UI-владелец claim-ит
завершённый report/error: in-flight remount принимает outcome, а последующий
remount после обработки не интерпретирует исторический результат повторно и
не показывает stale Snackbar/refresh. При logout, close или замене runtime
stale presentation continuation прекращается без новых owner-scoped
Home/Platform reads.
Повторный rebuild не отправляет `PENDING` и не увеличивает счётчик попыток.
После завершения первой попытки resume и retry UI перечитывают только
authoritative Home/Platform. Новая authenticated runtime после process restart
или 401 reauthentication получает новый однократный replay. Повторная
startup-попытка в той же сессии автоматически не запускается; явный
пользовательский retry из recovery center вызывает `replayPending`. Обычный
новый business submit сохраняет FIFO-семантику lane и поэтому может сначала
дренировать более старый `PENDING`.

### Owner-scoped recovery center

Authenticated UI показывает вход **«Сохранённые действия»** из первого пути,
home, путевого журнала и экрана аккаунта. Badge содержит только количество
локальных записей; отдельное состояние показывает, что store не удалось
прочитать.

Runtime возвращает presentation-модели только:

```text
command kind и lane
PENDING / FAILED
attempt count
coarse failure category
created/updated/last-attempt timestamps
```

Идентификатор записи остаётся приватным внутри core-модели и используется
только для owner-scoped compare-and-delete. Payload, idempotency key,
fingerprint, receipt, Health cursor, `lastError` и filesystem path в
presentation boundary не выходят.

### Безопасные действия

`PENDING` нельзя удалить: backend мог commit-нуть mutation до потери response.
Кнопка повтора запускает существующий `replayPending`, поэтому использует
сохранённые payload и idempotency key. После хотя бы одного успешного replay
application shell заново загружает authoritative home/platform state.
Ручной успех увеличивает refresh generation: незавершённый первый путь и
Home/Platform перечитывают server state без повторного startup replay. Уже
открытый основной shell не перемонтируется, поэтому выбранная вкладка и ввод
пользователя сохраняются.

`FAILED` означает подтверждённую terminal ошибку и автоматически больше не
отправляется. Blind retry запрещён: пользователь должен создать новое действие
из свежего server state. После подтверждения можно убрать только локальную
диагностическую запись; server state это не отменяет.

Store corruption отображается постоянно и fail-closed. Экран позволяет
повторить чтение, но не очищает, не перезаписывает и не показывает raw
diagnostics.

При переходе сессии из `authenticated` root navigator закрывает все
owner-scoped overlay routes, включая Account и Recovery. После возврата с
Recovery shell и уже открытый Account повторно читают безопасную сводку, чтобы
временное состояние недоступности store не оставалось висеть.

## Совместимость

- Envelope остаётся `version = 1`.
- `lastFailureCategory` является optional additive полем.
- Новый reader принимает старую запись без категории и неизвестную будущую
  категорию как `null`.
- Старый reader игнорирует additive поле; rollback сохраняет читаемость
  очереди, хотя снова использует старое разделение lane до обновления mobile.
- Backend API и Flyway schema не меняются.

## Последствия

Плюсы:

- alpha-пользователь видит незавершённую локальную доставку после restart;
- manual retry не создаёт новый key или optimistic state;
- telemetry не блокирует критический игровой handoff;
- terminal записи не исчезают без явного подтверждения;
- support UI не становится каналом утечки command payload.

Ограничения:

- replay остаётся foreground-only;
- reachability listener, background worker и автоматический таймер не
  добавляются;
- `FAILED` не retry-ится и не превращается обратно в `PENDING`;
- автоматический retention/pruning terminal записей отложен;
- восстановление повреждённого store требует отдельного support-решения и не
  выполняется UI-кнопкой.

## Альтернативы

### Разрешить удалять `PENDING`

Отклонено: клиент не знает, произошёл ли server commit перед потерей response.

### Повторять `FAILED`

Отклонено: terminal `4xx` или некорректный payload требуют нового решения на
актуальном server state, а не бесконечного replay старой команды.

### Хранить telemetry в `GAMEPLAY`

Отклонено: experiment exposure не должна задерживать debit, reward или
acknowledgement результата.

### Автоматически сбрасывать повреждённый store

Отклонено: пустая очередь выглядела бы как подтверждённая доставка и могла бы
скрыть неоднозначную mutation.
