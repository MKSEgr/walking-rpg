# Release notes — 0.1.0 technical candidate

Этот candidate объединяет первый playable, 18-узловую главу, platform journal,
durable mobile commands, server-authoritative economy/progression, risk shadow
mode, bounded operational surface и release-quality pipeline. Material
inventory теперь включает server-authoritative starter crafting recipe,
audited debit и persistent unique item с exact replay.

## Проверяемые артефакты

- backend executable JAR;
- Android unsigned release AAB;
- iOS release app без code signing;
- deterministic build metadata;
- SHA-256 для каждого candidate artifact.

CI дополнительно выполняет secret-free synthetic PostgreSQL backup/restore
round-trip. Его evidence имеет `scope=SYNTHETIC_CI` и
`productionValidated=false` и не является production artifact или датированным
restore evidence.

Артефакты не предназначены для прямой публикации: signing, store credentials,
production DNS/TLS/deployment, management network/WAF, alerts, реальный
backup/restore, device evidence и beta rollout остаются внешними gates.
