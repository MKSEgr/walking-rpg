# Autonomous batch 0001: second node and persistent inventory

- **Issue:** #26
- **Base:** `master`
- **Integration branch:** `batch/second-node-inventory`
- **Merge policy:** only the repository owner merges the final stable PR into `master`
- **Status:** in progress

## Objective

Extend the existing first playable without intermediate merges:

```text
resolved signal-source-v1
→ second expedition node
→ idempotent ENERGY spend
→ second event
→ material reward
→ persistent inventory
→ authoritative home/mobile state
```

## Execution rules

1. Work stays on this integration branch.
2. Technical choices that preserve the product objective do not require intermediate approval.
3. Migrations must preserve existing users and completed first-loop state.
4. All state-changing commands remain idempotent and transactionally atomic.
5. Mobile uses the durable outbox and reloads authoritative home state after success.
6. Required refactoring, tests, documentation and regression fixes are part of the batch.
7. No destructive data migration, production secret, signing, store publication or physical-device validation is performed.
8. The batch is complete only after self-review, a clean diff and all standard CI jobs are green.

## Work sequence

- [x] Model starter content v2 and migration from starter-v1 state
- [x] Persist second-node expedition state
- [x] Extend idempotent expedition advance
- [x] Implement second server-owned event and choices
- [x] Add persistent material inventory and reward protection
- [x] Extend `GET /api/v1/home`
- [x] Extend Flutter models, clients, durable commands and UI
- [x] Add unit/API/PostgreSQL/widget tests
- [x] Validate clean-schema and upgrade-schema paths
- [x] Update ADR/API/architecture/roadmap/backlog/README/changelog
- [ ] Remove temporary automation or diagnostic files
- [ ] Run and repair full CI until green
- [ ] Collapse the branch to a reviewable final history

## Completion evidence

The final PR description must contain:

- migration and backward-compatibility notes;
- API examples;
- transaction/idempotency guarantees;
- test scenarios;
- final CI run and all job conclusions;
- explicit list of intentionally deferred work.
