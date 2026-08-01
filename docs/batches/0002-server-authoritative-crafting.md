# Autonomous batch 0002: server-authoritative crafting

- **Base:** `master`
- **Integration branch:** `feat/server-authoritative-crafting`
- **Merge policy:** repository owner merges the reviewed PR into `master`
- **Status:** implementation complete; CI/review pending

## Objective

```text
persistent material rewards
→ server-owned recipe
→ atomic audited material debit
→ persistent unique item
→ additive home projection
→ durable mobile craft command
→ authoritative reload
```

## Execution rules

1. Recipe cost/result is never accepted from the client.
2. Multi-item debit, ledger, unique item and response use one transaction.
3. Replay returns the exact first response and never repeats consumption.
4. Mobile persists the command before send and does not update inventory
   optimistically.
5. Existing mobile/backend rolling compatibility stays additive.
6. Account export/delete and backup/restore must cover every new table.
7. No production secrets, signing, deployment or physical validation is
   performed by this batch.

## Work sequence

- [x] Define `crafting-v1` and `resonance-compass-v1`
- [x] Add V13 credit/debit ledger checks and crafting tables
- [x] Implement transaction lock, shortage rollback, exact replay and unique
      result
- [x] Extend home inventory/recipe projection
- [x] Add Flutter client, model, GAMEPLAY outbox command and workshop UI
- [x] Add unit/API/PostgreSQL/migration/widget tests
- [x] Extend account export/delete and synthetic backup/restore evidence
- [x] Update API, architecture, ADR, roadmap, backlog and README files
- [ ] Run and repair full CI/Release quality
- [ ] Complete final security/concurrency self-review
- [ ] Publish and review the final PR

## Deferred intentionally

- more recipes, rarity, upgrades and dismantling;
- operator-authored recipe CMS;
- production balance tuning from real cohort/economy data;
- physical-device and store-candidate validation already tracked as external
  gates.
