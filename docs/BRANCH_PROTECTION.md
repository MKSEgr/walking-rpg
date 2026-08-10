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
и `Release quality`, структурно разбирает все YAML mappings и отклоняет branch,
moving tag, shortened SHA, expression или Docker action без immutable digest.
Quoted keys, flow mappings и другие валидные YAML spellings не обходят gate.
Parser закреплён exact version и wheel SHA-256 в
`scripts/ci/action-pin-policy-requirements.txt`; несовпадение версии закрывает
проверку ошибкой.

Обновление Action выполняется отдельным reviewable PR: SHA сверяется с tag в
прямом upstream repository, изучаются release notes и diff, после чего заново
проходит полный release gate. Автоматический merge таких обновлений запрещён.
Rollback возвращает предыдущий reviewed SHA отдельным PR и также требует всех
проверок.

## Explicit GitHub-hosted runner images

Protected workflows используют только reviewed versioned labels
`ubuntu-24.04` и `macos-26`. Alias `ubuntu-latest`/`macos-latest` запрещены:
GitHub постепенно переводит их на новые major OS images, поэтому один source
SHA мог бы без изменения репозитория получить другую ОС, architecture или
Xcode toolchain.

`scripts/ci/verify_runner_image_pins.py` структурно разбирает каждый `.yml` и
`.yaml` workflow в `.github/workflows` и каждый job. Gate отклоняет непросмотренный
label, expression, collection, пропущенный `runs-on`, YAML alias/merge key,
duplicate key и несколько YAML documents. Parser использует тот же exact
PyYAML wheel, что immutable Action policy. Обновление runner OS выполняется
отдельным CODEOWNER-reviewed PR после зелёной platform matrix; silent fallback
на `-latest` запрещён.

Versioned hosted label фиксирует major OS/architecture boundary, но не exact
weekly VM image release: GitHub обновляет software внутри поддерживаемого image.
Exact image release и Included Software URL сохраняются в Actions job log. Для
побайтово контролируемой VM в будущем потребуется отдельный self-hosted image
contract; текущая политика не создаёт ложного утверждения об этом.

## Immutable build-tool wrapper downloads

Maven и Gradle wrapper properties связывают exact versioned distribution URL с
reviewed lowercase SHA-256. Unix и PowerShell Maven launchers вычисляют SHA-256
до распаковки и используют checksum-bound cache directory, поэтому ранее
скачанный непроверенный cache не считается доверенным. Gradle Wrapper применяет
штатный `distributionSha256Sum` до установки distribution.

`scripts/ci/verify_build_tool_wrapper_pins.py` запускается в standard CI и
`Release quality`. Gate требует exact Maven/Gradle property sets, отклоняет
missing/duplicate/malformed или изменённые URL/checksum и сверяет tracked
official Gradle 2.10 bootstrap JAR (поддерживающий checksum property) с его
опубликованным checksum. Regression suite
исполняет реальный временный Maven fixture: корректный ZIP запускается, а
несовпадающий checksum не может установить или выполнить fixture.

Обновление Maven, Gradle или wrapper JAR выполняется одним CODEOWNER-reviewed
PR после независимой сверки upstream checksum и полного backend/Android build
matrix. Изменение только URL, только checksum или только bootstrap JAR запрещено.

## Immutable backend base images

Protected `backend/Dockerfile` сохраняет человекочитаемые Eclipse Temurin tags,
но обе стадии закрепляет на reviewed multi-platform OCI index digest в форме
`tag@sha256:<64 lowercase hex>`. `scripts/ci/verify_backend_base_pins.py`
запускается в standard CI и `Release quality`: он требует ровно две стадии в
согласованном порядке, build alias и exact reviewed JDK/JRE refs. Moving tag,
digest-only ref, переменная, platform expression, дополнительная стадия или
другой digest закрывают gate ошибкой.

Обновление base image выполняется отдельным CODEOWNER-reviewed PR. Для каждого
tag сверяются OCI index digest и upstream metadata, после чего одновременно
обновляются Dockerfile, policy constants и независимые constants защищённого
publisher. Старый source с другими pins не пересобирается: rollback использует
уже опубликованный immutable application image digest.

## Immutable PostgreSQL test infrastructure

Все Java integration/migration/operations tests создают PostgreSQL через
`PostgresTestContainer`, который хранит один reviewed PostgreSQL 17 tag и
multi-platform OCI index digest. Локальный `compose.yaml` использует тот же
образ в форме `tag@sha256:<64 lowercase hex>`.

`scripts/ci/verify_postgres_image_pins.py` структурно проверяет Compose и
сканирует все Java test sources. Новый прямой `PostgreSQLContainer`
constructor, image literal вне factory, moving/digest-only/variable ref,
YAML alias, duplicate key или digest drift закрывают standard CI и
`Release quality` ошибкой. Обновление PostgreSQL выполняется отдельным
CODEOWNER-reviewed PR вместе с проверкой runner architectures и полным
PostgreSQL integration/restore контуром.

## Перед merge

- head PR не изменялся после последнего approval;
- standard CI зелёный;
- для release-срезов `Release quality` зелёный;
- remote Action refs прошли immutable-pin policy;
- GitHub-hosted jobs прошли explicit runner-image policy;
- Maven/Gradle distributions и Gradle wrapper JAR прошли checksum policy;
- protected backend base images прошли exact-digest policy;
- PostgreSQL Testcontainers и Compose прошли общий exact-digest policy;
- временные workflow/overlay-файлы отсутствуют;
- merge выполняется через `Squash and merge`.
