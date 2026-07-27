# Защита ветки `master`

## Фактическая модель

На репозитории активны два ruleset:

1. `master-owner-only` ограничивает обновление и удаление default branch.
2. `master-quality-gate` запрещает удаление и force-push, требует pull request, минимум одно одобрение, актуальное одобрение последнего push, закрытые review threads и review от CODEOWNER.

`.github/CODEOWNERS` назначает владельцем всех файлов `@MKSEgr`. У технического аккаунта разработки `serbin70` есть `Write` для feature-веток, но нет `Admin` или `Maintain`.

## Рабочий поток

```text
serbin70 / automation
→ feature branch
→ pull request
→ standard CI + Release quality
→ review @MKSEgr
→ Squash and merge владельцем
```

Настройки ruleset живут на GitHub. Этот документ фиксирует проверяемый процесс, но не подменяет enforcement платформы.

## Перед merge

- head PR не изменялся после последнего approval;
- standard CI зелёный;
- для release-срезов `Release quality` зелёный;
- временные workflow/overlay-файлы отсутствуют;
- merge выполняется через `Squash and merge`.
