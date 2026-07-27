# Device validation protocol

## Цель

Подтвердить, что приложение получает корректный aggregated daily total, не удваивает награды и устойчиво восстанавливается при изменениях health data и lifecycle ОС.

## Минимальная матрица

- iPhone без Apple Watch;
- iPhone с Apple Watch;
- Android с Health Connect;
- минимум два Android data provider;
- сценарий ручной записи и коррекции.

Для каждого запуска фиксируются модель, версия ОС, версия приложения, provider, timezone, локальная дата, разрешения и commit SHA.

## Сценарии

1. Чистая установка и разрешение только `STEPS READ`.
2. Повторная синхронизация того же total — без дополнительной награды.
3. Рост total — награда только за положительную delta.
4. Понижение total после удаления/коррекции — без отрицательной награды.
5. Ручная запись — best effort, не security boundary.
6. Отзыв и повторная выдача разрешения.
7. Переход через локальную полночь.
8. Смена IANA timezone.
9. Offline command → restart → replay с тем же idempotency key.
10. Resume fallback после длительного background.
11. Измерение батареи на согласованном интервале.

## Acceptance criteria

- backend high-watermark не уменьшается;
- один payload/key не создаёт две награды;
- два устройства не удваивают общий daily total;
- UI после reload совпадает с server-authoritative state;
- ошибки разрешений не ломают platform-журнал;
- evidence не содержит персональных health samples.

Шаблон: `docs/evidence/health-device-validation-template.md`.
