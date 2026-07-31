INSERT INTO app_user (
    user_id,
    created_at,
    last_seen_at,
    has_successful_activity_sync
) VALUES (
    'backup-drill-user',
    '2026-07-30T10:00:00Z',
    '2026-07-30T10:01:00Z',
    true
);

INSERT INTO app_device (
    user_id,
    device_id,
    created_at,
    last_seen_at
) VALUES (
    'backup-drill-user',
    'backup-drill-device',
    '2026-07-30T10:00:00Z',
    '2026-07-30T10:01:00Z'
);

INSERT INTO roadmap_user_state (
    user_id,
    state_json,
    version,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    '{
      "activePetId": "spark-v1",
      "completedOnboardingSteps": [
        "welcome",
        "health-permission",
        "first-sync",
        "pet-selection",
        "first-expedition",
        "first-event"
      ],
      "onboardingComplete": true
    }'::jsonb,
    4,
    '2026-07-30T10:00:00Z',
    '2026-07-30T10:00:40Z'
);

INSERT INTO processed_roadmap_command (
    user_id,
    command_type,
    idempotency_key,
    request_fingerprint,
    response_json,
    created_at
) VALUES (
    'backup-drill-user',
    'COMPLETE_ONBOARDING_STEP',
    'backup-drill-welcome',
    repeat('a', 64),
    '{
      "snapshot": {
        "stateVersion": 1,
        "userState": {
          "activePetId": null,
          "completedOnboardingSteps": ["welcome"],
          "onboardingComplete": false
        }
      }
    }'::jsonb,
    '2026-07-30T10:00:01Z'
);

INSERT INTO processed_roadmap_command (
    user_id,
    command_type,
    idempotency_key,
    request_fingerprint,
    response_json,
    created_at
) VALUES (
    'backup-drill-user',
    'SELECT_PET',
    'backup-drill-pet',
    repeat('b', 64),
    '{
      "snapshot": {
        "stateVersion": 2,
        "userState": {
          "activePetId": "spark-v1",
          "completedOnboardingSteps": ["welcome", "pet-selection"],
          "onboardingComplete": false
        }
      }
    }'::jsonb,
    '2026-07-30T10:00:05Z'
);

INSERT INTO activity_sync_state (
    user_id,
    local_date,
    accepted_total,
    state_version,
    time_zone,
    updated_at
) VALUES (
    'backup-drill-user',
    '2026-07-30',
    5000,
    1,
    'Europe/Berlin',
    '2026-07-30T10:00:10Z'
);

INSERT INTO processed_activity_sync (
    user_id,
    device_id,
    idempotency_key,
    request_fingerprint,
    accepted_total,
    accepted_delta,
    energy_granted,
    risk_status,
    state_version,
    server_time,
    created_at,
    energy_balance_after,
    economy_version
) VALUES (
    'backup-drill-user',
    'backup-drill-device',
    'backup-drill-activity',
    repeat('c', 64),
    5000,
    4000,
    40,
    'ACCEPTED',
    1,
    '2026-07-30T10:00:10Z',
    '2026-07-30T10:00:10Z',
    40,
    1
);

INSERT INTO activity_risk_assessment (
    user_id,
    device_id,
    local_date,
    authoritative_total,
    accepted_delta,
    risk_score,
    decision,
    signals,
    created_at
) VALUES (
    'backup-drill-user',
    'backup-drill-device',
    '2026-07-30',
    5000,
    4000,
    4,
    'ACCEPT',
    '["synthetic-drill"]'::jsonb,
    '2026-07-30T10:00:10Z'
);

INSERT INTO economy_wallet (
    user_id,
    currency_code,
    balance,
    version,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    'ENERGY',
    10,
    2,
    '2026-07-30T10:00:10Z',
    '2026-07-30T10:00:20Z'
);

INSERT INTO economy_ledger (
    ledger_entry_id,
    user_id,
    currency_code,
    amount,
    balance_after,
    wallet_version,
    reason_code,
    source_type,
    source_key,
    created_at
) VALUES (
    '10000000-0000-0000-0000-000000000001',
    'backup-drill-user',
    'ENERGY',
    40,
    40,
    1,
    'ACTIVITY_STEPS',
    'ACTIVITY_SYNC',
    'backup-drill-device:backup-drill-activity',
    '2026-07-30T10:00:10Z'
), (
    '10000000-0000-0000-0000-000000000002',
    'backup-drill-user',
    'ENERGY',
    -30,
    10,
    2,
    'EXPEDITION_ADVANCE',
    'EXPEDITION_ADVANCE',
    'starter-expedition-v1:backup-drill-advance',
    '2026-07-30T10:00:20Z'
);

INSERT INTO expedition_progress (
    user_id,
    expedition_id,
    current_node_id,
    progress_energy,
    required_energy,
    status,
    unlocked_event_id,
    version,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    'starter-expedition-v1',
    'lumen-gate',
    0,
    45,
    'IN_PROGRESS',
    NULL,
    2,
    '2026-07-30T10:00:15Z',
    '2026-07-30T10:00:30Z'
);

INSERT INTO processed_expedition_advance (
    user_id,
    expedition_id,
    idempotency_key,
    request_fingerprint,
    content_version,
    expedition_name,
    energy_spent,
    energy_balance_after,
    economy_version,
    progress_after,
    required_energy,
    expedition_version,
    expedition_status,
    current_node_id,
    current_node_name,
    event_id,
    event_title,
    event_summary,
    server_time,
    created_at
) VALUES (
    'backup-drill-user',
    'starter-expedition-v1',
    'backup-drill-advance',
    repeat('d', 64),
    'chapter-1-v1',
    'Сигнальный путь',
    30,
    10,
    2,
    30,
    30,
    1,
    'EVENT_READY',
    'outer-beacon',
    'Внешний маяк',
    'signal-source-v1',
    'Источник сигнала',
    'Synthetic backup drill event.',
    '2026-07-30T10:00:20Z',
    '2026-07-30T10:00:20Z'
);

INSERT INTO pilot_progress (
    user_id,
    pilot_id,
    level,
    current_experience,
    next_level_experience,
    version,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    'navigator-v1',
    1,
    10,
    100,
    1,
    '2026-07-30T10:00:25Z',
    '2026-07-30T10:00:30Z'
);

INSERT INTO pet_progress (
    user_id,
    pet_id,
    level,
    bond,
    version,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    'spark-v1',
    1,
    5,
    1,
    '2026-07-30T10:00:25Z',
    '2026-07-30T10:00:30Z'
);

INSERT INTO inventory_stack (
    user_id,
    item_id,
    quantity,
    version,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    'lumen-shard',
    2,
    1,
    '2026-07-30T10:00:30Z',
    '2026-07-30T10:00:30Z'
);

INSERT INTO inventory_ledger (
    ledger_entry_id,
    user_id,
    item_id,
    quantity_delta,
    quantity_after,
    inventory_version,
    reason_code,
    source_type,
    source_key,
    created_at
) VALUES (
    '20000000-0000-0000-0000-000000000001',
    'backup-drill-user',
    'lumen-shard',
    2,
    2,
    1,
    'EVENT_REWARD',
    'EVENT_RESOLUTION',
    'starter-expedition-v1:signal-source-v1',
    '2026-07-30T10:00:30Z'
);

INSERT INTO processed_event_resolution (
    user_id,
    expedition_id,
    event_id,
    idempotency_key,
    request_fingerprint,
    content_version,
    expedition_status,
    expedition_version,
    event_title,
    resolution_status,
    choice_id,
    choice_title,
    outcome_title,
    outcome_summary,
    pilot_id,
    pilot_name,
    pilot_level_after,
    pilot_experience_gained,
    pilot_experience_after,
    pilot_next_level_experience,
    pilot_version,
    pet_id,
    pet_name,
    pet_level_after,
    pet_bond_gained,
    pet_bond_after,
    pet_version,
    server_time,
    created_at,
    material_item_id,
    material_item_name,
    material_item_description,
    material_quantity_gained,
    material_quantity_after,
    material_version,
    receipt_id,
    handoff_required,
    next_node_id,
    next_node_name,
    acknowledged_at
) VALUES (
    'backup-drill-user',
    'starter-expedition-v1',
    'signal-source-v1',
    'backup-drill-resolution',
    repeat('e', 64),
    'chapter-1-v1',
    'IN_PROGRESS',
    2,
    'Источник сигнала',
    'RESOLVED',
    'stabilize-signal',
    'Стабилизировать сигнал',
    'Сигнал стабилен',
    'Synthetic backup drill resolution.',
    'navigator-v1',
    'Навигатор',
    1,
    10,
    10,
    100,
    1,
    'spark-v1',
    'Искра',
    1,
    5,
    5,
    1,
    '2026-07-30T10:00:30Z',
    '2026-07-30T10:00:30Z',
    'lumen-shard',
    'Люминовый осколок',
    'Synthetic material fixture.',
    2,
    2,
    1,
    '30000000-0000-0000-0000-000000000001',
    true,
    'lumen-gate',
    'Люменовые врата',
    NULL
);

UPDATE processed_event_resolution
SET acknowledged_at = '2026-07-30T10:00:31Z'
WHERE receipt_id = '30000000-0000-0000-0000-000000000001';

INSERT INTO processed_roadmap_command (
    user_id,
    command_type,
    idempotency_key,
    request_fingerprint,
    response_json,
    created_at
) VALUES (
    'backup-drill-user',
    'COMPLETE_ONBOARDING_STEP',
    'backup-drill-complete',
    repeat('f', 64),
    '{
      "snapshot": {
        "stateVersion": 4,
        "userState": {
          "activePetId": "spark-v1",
          "completedOnboardingSteps": [
            "welcome",
            "health-permission",
            "first-sync",
            "pet-selection",
            "first-expedition",
            "first-event"
          ],
          "onboardingComplete": true
        }
      }
    }'::jsonb,
    '2026-07-30T10:00:40Z'
);

INSERT INTO roadmap_squad (
    squad_id,
    squad_name,
    owner_user_id,
    created_at,
    updated_at
) VALUES (
    '40000000-0000-0000-0000-000000000001',
    'Synthetic Drill Squad',
    'backup-drill-user',
    '2026-07-30T10:00:45Z',
    '2026-07-30T10:00:45Z'
);

INSERT INTO roadmap_squad_member (
    squad_id,
    user_id,
    joined_at
) VALUES (
    '40000000-0000-0000-0000-000000000001',
    'backup-drill-user',
    '2026-07-30T10:00:45Z'
);

INSERT INTO platform_event (
    user_id,
    event_name,
    occurred_at,
    attributes,
    received_at
) VALUES (
    'backup-drill-user',
    'backup_restore_drill',
    '2026-07-30T10:00:50Z',
    '{"scope":"synthetic"}'::jsonb,
    '2026-07-30T10:00:50Z'
);

INSERT INTO platform_crash_report (
    user_id,
    platform,
    app_version,
    error_type,
    message,
    stack_trace,
    context,
    occurred_at,
    received_at
) VALUES (
    'backup-drill-user',
    'synthetic',
    '0.0.0-drill',
    'SyntheticDrillException',
    'Synthetic fixture only.',
    'synthetic-stack',
    '{"scope":"synthetic"}'::jsonb,
    '2026-07-30T10:00:51Z',
    '2026-07-30T10:00:51Z'
);

INSERT INTO push_registration (
    user_id,
    device_id,
    platform,
    provider,
    token_hash,
    enabled,
    created_at,
    updated_at
) VALUES (
    'backup-drill-user',
    'backup-drill-device',
    'synthetic',
    'disabled',
    repeat('1', 64),
    false,
    '2026-07-30T10:00:52Z',
    '2026-07-30T10:00:52Z'
);

INSERT INTO payment_intent (
    payment_intent_id,
    user_id,
    product_id,
    amount_minor,
    provider,
    provider_reference,
    status,
    idempotency_key,
    created_at,
    updated_at
) VALUES (
    '50000000-0000-0000-0000-000000000001',
    'backup-drill-user',
    'synthetic-product',
    199,
    'disabled',
    'synthetic-reference',
    'REJECTED',
    'backup-drill-payment',
    '2026-07-30T10:00:53Z',
    '2026-07-30T10:00:53Z'
);

INSERT INTO tester_cohort_member (
    cohort_code,
    user_id,
    status,
    notes,
    created_by,
    created_at,
    updated_at
) VALUES (
    'synthetic-drill',
    'backup-drill-user',
    'ACTIVE',
    'Synthetic fixture only.',
    'backup-restore-drill',
    '2026-07-30T10:00:54Z',
    '2026-07-30T10:00:54Z'
);

INSERT INTO account_deletion_receipt (
    subject_hash,
    receipt_id,
    request_key_hash,
    requested_at,
    completed_at
) VALUES (
    repeat('2', 64),
    '60000000-0000-0000-0000-000000000001',
    repeat('3', 64),
    '2026-07-30T10:00:55Z',
    '2026-07-30T10:00:56Z'
);
