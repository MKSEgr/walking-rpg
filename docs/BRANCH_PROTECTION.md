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

## Immutable Actions

Remote GitHub Actions во всех workflow закрепляются на полном 40-символьном
commit SHA. Релизный tag рядом с SHA — только review/update metadata; workflow
его не исполняет. `scripts/ci/verify_action_pins.py` запускается в standard CI
и `Release quality` и отклоняет branch, moving tag, shortened SHA, expression
или Docker action без immutable digest.

Обновление Action выполняется отдельным reviewable PR: SHA сверяется с tag в
прямом upstream repository, изучаются release notes и diff, после чего заново
проходит полный release gate. Автоматический merge таких обновлений запрещён.
Rollback возвращает предыдущий reviewed SHA отдельным PR и также требует всех
проверок.

## Перед merge

- head PR не изменялся после последнего approval;
- standard CI зелёный;
- для release-срезов `Release quality` зелёный;
- remote Action refs прошли immutable-pin policy;
- временные workflow/overlay-файлы отсутствуют;
- merge выполняется через `Squash and merge`.
