CREATE TABLE expedition_progress (
    user_id varchar(128) NOT NULL,
    expedition_id varchar(64) NOT NULL,
    current_node_id varchar(64) NOT NULL,
    progress_energy bigint NOT NULL DEFAULT 0 CHECK (progress_energy >= 0),
    required_energy bigint NOT NULL CHECK (required_energy > 0),
    status varchar(32) NOT NULL,
    unlocked_event_id varchar(64),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, expedition_id),
    CONSTRAINT ck_expedition_progress_id
        CHECK (btrim(expedition_id) <> ''),
    CONSTRAINT ck_expedition_progress_node
        CHECK (btrim(current_node_id) <> ''),
    CONSTRAINT ck_expedition_progress_limit
        CHECK (progress_energy <= required_energy),
    CONSTRAINT ck_expedition_progress_status
        CHECK (status IN ('IN_PROGRESS', 'EVENT_READY')),
    CONSTRAINT ck_expedition_progress_event_state
        CHECK (
            (status = 'IN_PROGRESS' AND unlocked_event_id IS NULL)
            OR (status = 'EVENT_READY' AND unlocked_event_id IS NOT NULL)
        ),
    CONSTRAINT fk_expedition_progress_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE processed_expedition_advance (
    user_id varchar(128) NOT NULL,
    expedition_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint char(64) NOT NULL,
    content_version varchar(64) NOT NULL,
    expedition_name varchar(200) NOT NULL,
    energy_spent bigint NOT NULL CHECK (energy_spent > 0),
    energy_balance_after bigint NOT NULL CHECK (energy_balance_after >= 0),
    economy_version bigint NOT NULL CHECK (economy_version > 0),
    progress_after bigint NOT NULL CHECK (progress_after >= 0),
    required_energy bigint NOT NULL CHECK (required_energy > 0),
    expedition_version bigint NOT NULL CHECK (expedition_version > 0),
    expedition_status varchar(32) NOT NULL,
    current_node_id varchar(64) NOT NULL,
    current_node_name varchar(200) NOT NULL,
    event_id varchar(64),
    event_title varchar(200),
    event_summary text,
    server_time timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, expedition_id, idempotency_key),
    CONSTRAINT ck_processed_expedition_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_processed_expedition_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_expedition_progress
        CHECK (progress_after <= required_energy),
    CONSTRAINT ck_processed_expedition_status
        CHECK (expedition_status IN ('IN_PROGRESS', 'EVENT_READY')),
    CONSTRAINT ck_processed_expedition_event
        CHECK (
            (expedition_status = 'IN_PROGRESS'
                AND event_id IS NULL
                AND event_title IS NULL
                AND event_summary IS NULL)
            OR (expedition_status = 'EVENT_READY'
                AND event_id IS NOT NULL
                AND event_title IS NOT NULL
                AND event_summary IS NOT NULL)
        ),
    CONSTRAINT fk_processed_expedition_progress
        FOREIGN KEY (user_id, expedition_id)
        REFERENCES expedition_progress (user_id, expedition_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_expedition_advance_created_at
    ON processed_expedition_advance (user_id, created_at DESC);
