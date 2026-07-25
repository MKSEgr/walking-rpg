CREATE TABLE app_user (
    user_id varchar(128) PRIMARY KEY,
    created_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL
);

CREATE TABLE app_device (
    user_id varchar(128) NOT NULL,
    device_id varchar(128) NOT NULL,
    created_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, device_id),
    CONSTRAINT fk_app_device_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE activity_sync_state (
    user_id varchar(128) NOT NULL,
    device_id varchar(128) NOT NULL,
    local_date date NOT NULL,
    accepted_total bigint NOT NULL CHECK (accepted_total >= 0),
    state_version bigint NOT NULL CHECK (state_version >= 0),
    time_zone varchar(64) NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, device_id, local_date),
    CONSTRAINT fk_activity_sync_state_device
        FOREIGN KEY (user_id, device_id)
        REFERENCES app_device (user_id, device_id)
        ON DELETE CASCADE
);

CREATE TABLE processed_activity_sync (
    user_id varchar(128) NOT NULL,
    device_id varchar(128) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint varchar(64) NOT NULL,
    accepted_total bigint NOT NULL CHECK (accepted_total >= 0),
    accepted_delta bigint NOT NULL CHECK (accepted_delta >= 0),
    energy_granted bigint NOT NULL CHECK (energy_granted >= 0),
    risk_status varchar(32) NOT NULL,
    state_version bigint NOT NULL CHECK (state_version >= 0),
    server_time timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, device_id, idempotency_key),
    CONSTRAINT ck_processed_activity_sync_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_activity_sync_risk_status
        CHECK (risk_status IN ('ACCEPTED', 'NO_NEW_ACTIVITY', 'TOTAL_DECREASED')),
    CONSTRAINT fk_processed_activity_sync_device
        FOREIGN KEY (user_id, device_id)
        REFERENCES app_device (user_id, device_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_activity_sync_created_at
    ON processed_activity_sync (created_at);
