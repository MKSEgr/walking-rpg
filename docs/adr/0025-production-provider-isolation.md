# ADR 0025: production provider isolation

- Status: Accepted
- Date: 2026-07-30

## Context

The platform has provider interfaces for payments and push, but currently only
implements sandbox payment and development push. Registering either provider
unconditionally is unsafe: remote config could expose an action in a release
build and a protected backend could execute a development-only operation.

The existing `prod` profile protected authentication but did not define the
whole runtime boundary. A local-default datasource could still be selected
accidentally, and a PostgreSQL URL without verified TLS could reach startup.
`stage` needs the same fail-closed rules as `prod`; it is not a development
escape hatch.

## Decision

### Protected runtime profiles

`local` and `test` are development profiles. `stage` and `prod` are protected
profiles. A protected profile:

- cannot be combined with `local` or `test`;
- requires JWT authentication and disabled demo endpoints;
- requires explicit datasource URL, username and password;
- accepts only a PostgreSQL JDBC URL with a canonical DNS host and the sole
  raw query `sslmode=verify-full`; encoded/alias parameters, legacy numeric
  hosts, multi-host forms and Hikari/Flyway connection overrides are rejected
  during startup.

Configuration files contain no production secret or usable production
credential. The protected deployment environment must inject real database
and OIDC values.

### Provider selection

Provider selection is explicit:

```text
walking-rpg.providers.payment = sandbox | disabled
walking-rpg.providers.push    = development | disabled
```

The base configuration is fail-closed. `application-local.yml` explicitly
selects `sandbox` and `development`; `application-stage.yml` and
`application-prod.yml` explicitly select `disabled`.

Sandbox payment and development push are created only when both conditions
hold:

1. the matching provider property is selected; and
2. an active profile is `local` or `test`.

The `disabled` modes inject fail-closed providers which reject the operation.
The runtime guard rejects a development provider mode outside `local`/`test`
and rejects unknown modes.

For a new purchase, provider availability is checked after the idempotency
replay lookup but before creation of user or payment state. A saved command
replay preserves its command outcome and user state without another provider
call or mutation. Capability fields are deliberately re-projected from the
current deployment, so `sandboxPaymentsEnabled` may become false after the
provider is disabled. A new unavailable purchase has zero mutation.

### Remote config and mobile

Flyway V12 disables `sandboxPaymentsEnabled` and
`backgroundHealthSyncEnabled` in every existing remote-config snapshot. This
is a data-safe default, not the security boundary: backend provider
availability is authoritative.

Backend exposes an effective `sandboxPaymentsEnabled` value: the remote flag is
true only when the selected payment provider is available. Mobile renders a
sandbox purchase action only outside release builds and for a fresh snapshot
with that effective value set to true. A cached snapshot remains read-only and
does not expose the action.

The effective platform config also keeps `backgroundHealthSyncEnabled=false`;
foreground/resume behavior is not reclassified as guaranteed production
background delivery.

### Verification

Runtime tests cover profile combinations, datasource validation, provider
selection and no-side-effect rejection. Mobile tests cover effective
availability and cached-snapshot behavior. Release-readiness checks pin
the protected profile files, V12, provider conditions and release UI gate.

`ProductionRuntimeGuard` is the canonical validator.
`ProductionEnvironmentPostProcessor` delegates the protected datasource check
to it before context, DataSource or Flyway creation; the runtime bean validates
the same profile topology together with resolved provider properties.

## Consequences

- A protected runtime cannot accidentally use sandbox payment or development
  push.
- Remote config remains useful for product rollout but cannot grant a
  capability absent from the runtime/build.
- Local development opts into development providers explicitly.
- `stage` behaves like production for security boundaries.
- Adding App Store/Google Play billing or APNs/FCM requires production
  providers, credentials, lifecycle handling and external evidence.
- Real production datasource provisioning, deployment, monitoring,
  backup/restore drill, signing, store submission and physical-device
  validation remain external gates.
- The secret-free synthetic round-trip from ADR 0026 validates tooling only
  and does not satisfy the real backup/restore gate above.
