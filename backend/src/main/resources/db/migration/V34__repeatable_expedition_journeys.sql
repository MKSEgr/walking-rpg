CREATE TABLE expedition_journey_cycle (
    user_id VARCHAR(128) NOT NULL,
    expedition_id VARCHAR(64) NOT NULL,
    journey_number BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, expedition_id),
    CONSTRAINT ck_expedition_journey_cycle_number
        CHECK (journey_number >= 1),
    CONSTRAINT fk_expedition_journey_cycle_progress
        FOREIGN KEY (user_id, expedition_id)
        REFERENCES expedition_progress (user_id, expedition_id)
        ON DELETE CASCADE
);

INSERT INTO expedition_journey_cycle (
    user_id,
    expedition_id,
    journey_number,
    created_at,
    updated_at
)
SELECT user_id,
       expedition_id,
       1,
       created_at,
       updated_at
FROM expedition_progress;

ALTER TABLE processed_event_resolution
    ADD COLUMN journey_number BIGINT NOT NULL DEFAULT 1,
    DROP CONSTRAINT uq_processed_event_once,
    ADD CONSTRAINT uq_processed_event_once_per_journey
        UNIQUE (user_id, expedition_id, event_id, journey_number),
    ADD CONSTRAINT ck_processed_event_journey_number
        CHECK (journey_number >= 1);

CREATE TABLE processed_expedition_journey_start (
    user_id VARCHAR(128) NOT NULL,
    expedition_id VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    content_version VARCHAR(64) NOT NULL,
    expedition_name VARCHAR(128) NOT NULL,
    journey_number BIGINT NOT NULL,
    progress_after BIGINT NOT NULL,
    required_energy BIGINT NOT NULL,
    expedition_version BIGINT NOT NULL,
    expedition_status VARCHAR(32) NOT NULL,
    current_node_id VARCHAR(64) NOT NULL,
    current_node_name VARCHAR(128) NOT NULL,
    server_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, expedition_id, idempotency_key),
    CONSTRAINT ck_processed_expedition_journey_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_expedition_journey_number
        CHECK (journey_number >= 2),
    CONSTRAINT ck_processed_expedition_journey_progress
        CHECK (progress_after = 0 AND required_energy > 0),
    CONSTRAINT ck_processed_expedition_journey_version
        CHECK (expedition_version > 0),
    CONSTRAINT ck_processed_expedition_journey_status
        CHECK (expedition_status = 'IN_PROGRESS'),
    CONSTRAINT fk_processed_expedition_journey_progress
        FOREIGN KEY (user_id, expedition_id)
        REFERENCES expedition_progress (user_id, expedition_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_expedition_journey_start_created_at
    ON processed_expedition_journey_start (created_at);
