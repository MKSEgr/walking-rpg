# DigitalOcean stage deployment evidence — template

Do not commit or publish this file as completed evidence until the real checks
were performed. Never include credentials, CA contents, tokens, raw logs,
identity data or health data.

## Identity

| Field | Value |
|---|---|
| Environment | `walking-rpg-alpha-eu` |
| Provider / region | DigitalOcean / `fra` |
| UTC start / finish | `BLOCKED` |
| Hosting / Release Owner | `@MKSEgr` |
| Approved source SHA / tree | `BLOCKED` |
| Publisher provenance baseline SHA | `BLOCKED` |
| GHCR image / immutable digest | `BLOCKED` |
| Publisher workflow / receipt artifact digest | `BLOCKED` |
| App deployment ID / deployed image digest | `BLOCKED` |
| Previous safe deployment ID | `BLOCKED` |
| Backend component / size / count | `backend` / `apps-s-1vcpu-1gb` / `1` |
| PostgreSQL engine / topology | `17` / one Standard node, no standby |
| Public TLS endpoint | `BLOCKED` |

## Redacted configuration result

| Control | Result | Evidence link |
|---|---|---|
| No Git branch/image tag; exact image digest matched | `BLOCKED` | `BLOCKED` |
| Source descended from the publisher provenance baseline | `BLOCKED` | `BLOCKED` |
| Published image labels/files/user/entrypoint matched | `BLOCKED` | `BLOCKED` |
| Embedded source SHA/tree matched approved receipt at startup | `BLOCKED` | `BLOCKED` |
| Custom DB/database role; no admin role in app | `BLOCKED` | `BLOCKED` |
| Trusted Sources limited to reviewed app/drill source | `BLOCKED` | `BLOCKED` |
| Canonical DNS + provider CA + `sslmode=verify-full` | `BLOCKED` | `BLOCKED` |
| Runtime role privilege flags all false | `BLOCKED` | `BLOCKED` |
| Flyway latest version successful | `BLOCKED` | `BLOCKED` |
| JWT issuer/audience/claims fail closed | `BLOCKED` | `BLOCKED` |
| Payment/push development providers unavailable | `BLOCKED` | `BLOCKED` |
| Management listener unreachable publicly | `BLOCKED` | `BLOCKED` |
| `/livez` independent of DB | `BLOCKED` | `BLOCKED` |
| `/readyz` removes DB-unready instance | `BLOCKED` | `BLOCKED` |
| Enhanced Threat Control mobile smoke | `BLOCKED` | `BLOCKED` |

## Observability result

| Control | Result | Evidence link |
|---|---|---|
| Deployment/CPU/RAM/restart policies present | `BLOCKED` | `BLOCKED` |
| Notification destination and one delivered alert | `BLOCKED` | `BLOCKED` |
| Dashboard links and access policy | `BLOCKED` | `BLOCKED` |
| Runtime log destination / retention / access | `BLOCKED` | `BLOCKED` |
| Redaction review | `BLOCKED` | `BLOCKED` |

## Recovery result

| Control | Result | Evidence link |
|---|---|---|
| Backup/PITR policy and recovery window | `BLOCKED` | `BLOCKED` |
| Previous deployment rollback target available | `BLOCKED` | `BLOCKED` |
| Schema/content compatibility reviewed | `BLOCKED` | `BLOCKED` |
| TASK-009 real restore link | `BLOCKED` | `BLOCKED` |
| TASK-010 alert/stop/rollback drill link | `BLOCKED` | `BLOCKED` |

## Deviations and decision

- Deviations / linked defects: `BLOCKED`.
- Secret or personal-data exposure: `NO / BLOCKED`.
- Final state: `BLOCKED` (`VALIDATED`, `FIX_AND_RERUN` or `STOP`).
- Release Owner decision / UTC timestamp: `BLOCKED`.
