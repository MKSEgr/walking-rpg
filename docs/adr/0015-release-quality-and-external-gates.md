# ADR 0015: Release-quality CI и внешние gates

- Статус: принято
- Дата: 2026-07-27

## Контекст

Обычный CI подтверждает compile, tests и debug host builds, но не доказывает готовность к signing/store submission. Подпись, реальные устройства, APNs/FCM, store billing и beta-пользователи зависят от внешних credentials и evidence.

## Решение

1. Добавить отдельный workflow `Release quality`.
2. Собирать backend JAR, Android unsigned release AAB и iOS release app без code signing.
3. Генерировать deterministic build metadata из commit time и версионируемых файлов.
4. Запретить debug signing release-варианта.
5. Не хранить signing material в репозитории.
6. Разделять `CODE_COMPLETE`, `EXTERNAL_VALIDATION_REQUIRED` и `VALIDATED`.
7. Требовать ручной owner approval перед protected signing/publishing.
8. Выполнять protected jobs только на явно выбранных versioned runner labels:
   `ubuntu-24.04` и `macos-26`; `-latest` и непросмотренные labels отклонять
   структурным repository gate во всех workflow.
9. Связать Maven/Gradle wrapper distribution URLs с reviewed SHA-256,
   проверять Maven ZIP до extraction в обоих launchers и закрепить tracked
   Gradle wrapper JAR отдельным fail-closed repository gate.

## Последствия

- любой PR проверяется как release candidate без секретов;
- CI-артефакты сами по себе не публикуемы;
- store/device readiness подтверждается checklist и evidence;
- повторная генерация metadata для тех же inputs побайтно идентична.
- major OS/architecture runner boundary не меняется через migration alias без
  review; weekly GitHub-hosted image updates остаются явно зафиксированным
  ограничением и отражаются exact image version в job log.
- build-tool distribution не может незаметно измениться при том же source SHA;
  upgrade URL/checksum/bootstrap bytes требует отдельного reviewed PR и полной
  backend/mobile platform matrix.
