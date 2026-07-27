CREATE TABLE activity_risk_assessment (
    assessment_id bigserial PRIMARY KEY,
    user_id varchar(128) NOT NULL,
    device_id varchar(128) NOT NULL,
    local_date date NOT NULL,
    authoritative_total bigint NOT NULL CHECK (authoritative_total >= 0),
    accepted_delta bigint NOT NULL CHECK (accepted_delta >= 0),
    risk_score integer NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    decision varchar(16) NOT NULL CHECK (decision IN ('ACCEPT', 'REVIEW', 'BLOCK')),
    signals jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_activity_risk_signals_array
        CHECK (jsonb_typeof(signals) = 'array'),
    CONSTRAINT fk_activity_risk_device
        FOREIGN KEY (user_id, device_id)
        REFERENCES app_device (user_id, device_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_activity_risk_user_created_at
    ON activity_risk_assessment (user_id, created_at DESC);

CREATE INDEX ix_activity_risk_decision_created_at
    ON activity_risk_assessment (decision, created_at DESC);

CREATE TABLE roadmap_user_state (
    user_id varchar(128) PRIMARY KEY,
    state_json jsonb NOT NULL,
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT ck_roadmap_user_state_object
        CHECK (jsonb_typeof(state_json) = 'object'),
    CONSTRAINT fk_roadmap_user_state_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE processed_roadmap_command (
    user_id varchar(128) NOT NULL,
    command_type varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint char(64) NOT NULL,
    response_json jsonb NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, command_type, idempotency_key),
    CONSTRAINT ck_processed_roadmap_command_type
        CHECK (btrim(command_type) <> ''),
    CONSTRAINT ck_processed_roadmap_command_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_processed_roadmap_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_roadmap_response_object
        CHECK (jsonb_typeof(response_json) = 'object'),
    CONSTRAINT fk_processed_roadmap_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_roadmap_created_at
    ON processed_roadmap_command (user_id, created_at DESC);

CREATE TABLE remote_config_snapshot (
    config_version varchar(64) PRIMARY KEY,
    config_json jsonb NOT NULL,
    is_active boolean NOT NULL DEFAULT false,
    created_by varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_remote_config_version
        CHECK (btrim(config_version) <> ''),
    CONSTRAINT ck_remote_config_object
        CHECK (jsonb_typeof(config_json) = 'object')
);

CREATE UNIQUE INDEX uq_remote_config_single_active
    ON remote_config_snapshot ((is_active))
    WHERE is_active;

CREATE TABLE content_release (
    content_version varchar(64) PRIMARY KEY,
    release_notes text NOT NULL,
    content_json jsonb NOT NULL,
    is_active boolean NOT NULL DEFAULT false,
    created_by varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_content_release_version
        CHECK (btrim(content_version) <> ''),
    CONSTRAINT ck_content_release_notes
        CHECK (btrim(release_notes) <> ''),
    CONSTRAINT ck_content_release_object
        CHECK (jsonb_typeof(content_json) = 'object')
);

CREATE UNIQUE INDEX uq_content_release_single_active
    ON content_release ((is_active))
    WHERE is_active;

CREATE TABLE roadmap_squad (
    squad_id uuid PRIMARY KEY,
    squad_name varchar(160) NOT NULL,
    owner_user_id varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT ck_roadmap_squad_name
        CHECK (btrim(squad_name) <> ''),
    CONSTRAINT fk_roadmap_squad_owner
        FOREIGN KEY (owner_user_id)
        REFERENCES app_user (user_id)
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_roadmap_squad_name_ci
    ON roadmap_squad (lower(btrim(squad_name)));

CREATE TABLE roadmap_squad_member (
    squad_id uuid NOT NULL,
    user_id varchar(128) NOT NULL,
    joined_at timestamptz NOT NULL,
    PRIMARY KEY (squad_id, user_id),
    CONSTRAINT uq_roadmap_squad_member_user UNIQUE (user_id),
    CONSTRAINT fk_roadmap_squad_member_squad
        FOREIGN KEY (squad_id)
        REFERENCES roadmap_squad (squad_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_roadmap_squad_member_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_roadmap_squad_member_joined_at
    ON roadmap_squad_member (squad_id, joined_at, user_id);

CREATE TABLE platform_event (
    event_id bigserial PRIMARY KEY,
    user_id varchar(128),
    event_name varchar(128) NOT NULL,
    occurred_at timestamptz NOT NULL,
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    received_at timestamptz NOT NULL,
    CONSTRAINT ck_platform_event_name
        CHECK (btrim(event_name) <> ''),
    CONSTRAINT ck_platform_event_attributes_object
        CHECK (jsonb_typeof(attributes) = 'object'),
    CONSTRAINT fk_platform_event_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_platform_event_user_occurred_at
    ON platform_event (user_id, occurred_at DESC);

CREATE INDEX ix_platform_event_name_occurred_at
    ON platform_event (event_name, occurred_at DESC);

CREATE TABLE platform_crash_report (
    report_id bigserial PRIMARY KEY,
    user_id varchar(128),
    platform varchar(32) NOT NULL,
    app_version varchar(64) NOT NULL,
    error_type varchar(160) NOT NULL,
    message text NOT NULL,
    stack_trace text,
    context jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    CONSTRAINT ck_platform_crash_platform
        CHECK (btrim(platform) <> ''),
    CONSTRAINT ck_platform_crash_app_version
        CHECK (btrim(app_version) <> ''),
    CONSTRAINT ck_platform_crash_error_type
        CHECK (btrim(error_type) <> ''),
    CONSTRAINT ck_platform_crash_message
        CHECK (btrim(message) <> ''),
    CONSTRAINT ck_platform_crash_context_object
        CHECK (jsonb_typeof(context) = 'object'),
    CONSTRAINT fk_platform_crash_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_platform_crash_received_at
    ON platform_crash_report (received_at DESC);

CREATE TABLE push_registration (
    user_id varchar(128) NOT NULL,
    device_id varchar(128) NOT NULL,
    platform varchar(32) NOT NULL,
    provider varchar(32) NOT NULL,
    token_hash char(64) NOT NULL,
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, device_id),
    CONSTRAINT ck_push_registration_platform
        CHECK (btrim(platform) <> ''),
    CONSTRAINT ck_push_registration_provider
        CHECK (btrim(provider) <> ''),
    CONSTRAINT ck_push_registration_token_hash
        CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT fk_push_registration_device
        FOREIGN KEY (user_id, device_id)
        REFERENCES app_device (user_id, device_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_push_registration_enabled
    ON push_registration (user_id)
    WHERE enabled;

CREATE TABLE payment_intent (
    payment_intent_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id varchar(128) NOT NULL,
    product_id varchar(128) NOT NULL,
    amount_minor bigint NOT NULL CHECK (amount_minor > 0),
    provider varchar(64) NOT NULL,
    provider_reference varchar(160) NOT NULL,
    status varchar(32) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT ck_payment_product
        CHECK (btrim(product_id) <> ''),
    CONSTRAINT ck_payment_provider
        CHECK (btrim(provider) <> ''),
    CONSTRAINT ck_payment_reference
        CHECK (btrim(provider_reference) <> ''),
    CONSTRAINT ck_payment_status
        CHECK (btrim(status) <> ''),
    CONSTRAINT ck_payment_idempotency_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT uq_payment_intent_idempotency
        UNIQUE (user_id, idempotency_key),
    CONSTRAINT fk_payment_intent_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_payment_intent_user_created_at
    ON payment_intent (user_id, created_at DESC);

CREATE TABLE tester_cohort_member (
    cohort_code varchar(64) NOT NULL,
    user_id varchar(128) NOT NULL,
    status varchar(32) NOT NULL,
    notes text,
    created_by varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (cohort_code, user_id),
    CONSTRAINT ck_tester_cohort_code
        CHECK (btrim(cohort_code) <> ''),
    CONSTRAINT ck_tester_cohort_status
        CHECK (btrim(status) <> ''),
    CONSTRAINT fk_tester_cohort_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_tester_cohort_status
    ON tester_cohort_member (cohort_code, status, user_id);

CREATE INDEX ix_processed_activity_sync_retention
    ON processed_activity_sync (created_at, user_id, device_id);

INSERT INTO remote_config_snapshot (
    config_version,
    config_json,
    is_active,
    created_by,
    created_at
) VALUES (
    'roadmap-v1',
    '{
      "backgroundHealthSyncEnabled": false,
      "activityRetentionDays": 30,
      "seasonId": "signal-season-1",
      "weeklyRouteEnergy": 100,
      "sandboxPaymentsEnabled": true,
      "weeklyRouteEnabled": true
    }'::jsonb,
    true,
    'flyway',
    now()
);

INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
) VALUES (
    'chapter-1-v1',
    'Первая глава: 18 последовательных узлов.',
    '{"contentVersion":"chapter-1-v1","chapterId":"signal-chapter-1","nodeCount":18}'::jsonb,
    true,
    'flyway',
    now()
);

-- Users who resolved the former terminal second event continue at the third node.
-- Historical idempotent responses remain immutable in processed_event_resolution.
UPDATE expedition_progress progress
SET current_node_id = 'ash-orbit',
    progress_energy = 0,
    required_energy = 55,
    status = 'IN_PROGRESS',
    unlocked_event_id = NULL,
    version = progress.version + 1,
    updated_at = now()
WHERE progress.expedition_id = 'starter-expedition-v1'
  AND progress.current_node_id = 'lumen-gate'
  AND progress.status = 'COMPLETED'
  AND progress.unlocked_event_id = 'echo-vault-v1'
  AND EXISTS (
      SELECT 1
      FROM processed_event_resolution resolution
      WHERE resolution.user_id = progress.user_id
        AND resolution.expedition_id = progress.expedition_id
        AND resolution.event_id = 'echo-vault-v1'
  );
