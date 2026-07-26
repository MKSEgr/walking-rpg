ALTER TABLE expedition_progress
    DROP CONSTRAINT ck_expedition_progress_status,
    DROP CONSTRAINT ck_expedition_progress_event_state;

ALTER TABLE expedition_progress
    ADD CONSTRAINT ck_expedition_progress_status
        CHECK (status IN ('IN_PROGRESS', 'EVENT_READY', 'COMPLETED')),
    ADD CONSTRAINT ck_expedition_progress_event_state
        CHECK (
            (status = 'IN_PROGRESS'
                AND unlocked_event_id IS NULL)
            OR (status IN ('EVENT_READY', 'COMPLETED')
                AND unlocked_event_id IS NOT NULL
                AND progress_energy = required_energy)
        );

CREATE TABLE pilot_progress (
    user_id varchar(128) NOT NULL,
    pilot_id varchar(64) NOT NULL,
    level integer NOT NULL CHECK (level > 0),
    current_experience integer NOT NULL CHECK (current_experience >= 0),
    next_level_experience integer NOT NULL CHECK (next_level_experience > 0),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, pilot_id),
    CONSTRAINT ck_pilot_progress_id CHECK (btrim(pilot_id) <> ''),
    CONSTRAINT ck_pilot_progress_threshold
        CHECK (current_experience < next_level_experience),
    CONSTRAINT fk_pilot_progress_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE pet_progress (
    user_id varchar(128) NOT NULL,
    pet_id varchar(64) NOT NULL,
    level integer NOT NULL CHECK (level > 0),
    bond integer NOT NULL CHECK (bond >= 0),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, pet_id),
    CONSTRAINT ck_pet_progress_id CHECK (btrim(pet_id) <> ''),
    CONSTRAINT fk_pet_progress_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE processed_event_resolution (
    user_id varchar(128) NOT NULL,
    expedition_id varchar(64) NOT NULL,
    event_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint char(64) NOT NULL,
    content_version varchar(64) NOT NULL,
    expedition_status varchar(32) NOT NULL,
    expedition_version bigint NOT NULL CHECK (expedition_version > 0),
    event_title varchar(200) NOT NULL,
    resolution_status varchar(32) NOT NULL,
    choice_id varchar(64) NOT NULL,
    choice_title varchar(200) NOT NULL,
    outcome_title varchar(200) NOT NULL,
    outcome_summary text NOT NULL,
    pilot_id varchar(64) NOT NULL,
    pilot_name varchar(200) NOT NULL,
    pilot_level_after integer NOT NULL CHECK (pilot_level_after > 0),
    pilot_experience_gained integer NOT NULL CHECK (pilot_experience_gained >= 0),
    pilot_experience_after integer NOT NULL CHECK (pilot_experience_after >= 0),
    pilot_next_level_experience integer NOT NULL CHECK (pilot_next_level_experience > 0),
    pilot_version bigint NOT NULL CHECK (pilot_version > 0),
    pet_id varchar(64) NOT NULL,
    pet_name varchar(200) NOT NULL,
    pet_level_after integer NOT NULL CHECK (pet_level_after > 0),
    pet_bond_gained integer NOT NULL CHECK (pet_bond_gained >= 0),
    pet_bond_after integer NOT NULL CHECK (pet_bond_after >= 0),
    pet_version bigint NOT NULL CHECK (pet_version > 0),
    server_time timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, event_id, idempotency_key),
    CONSTRAINT uq_processed_event_once
        UNIQUE (user_id, expedition_id, event_id),
    CONSTRAINT ck_processed_event_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_processed_event_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_event_expedition_status
        CHECK (expedition_status = 'COMPLETED'),
    CONSTRAINT ck_processed_event_resolution_status
        CHECK (resolution_status = 'RESOLVED'),
    CONSTRAINT ck_processed_event_reward
        CHECK (pilot_experience_gained > 0 OR pet_bond_gained > 0),
    CONSTRAINT ck_processed_event_pilot_threshold
        CHECK (pilot_experience_after < pilot_next_level_experience),
    CONSTRAINT fk_processed_event_expedition
        FOREIGN KEY (user_id, expedition_id)
        REFERENCES expedition_progress (user_id, expedition_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_processed_event_pilot
        FOREIGN KEY (user_id, pilot_id)
        REFERENCES pilot_progress (user_id, pilot_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_processed_event_pet
        FOREIGN KEY (user_id, pet_id)
        REFERENCES pet_progress (user_id, pet_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_event_resolution_created_at
    ON processed_event_resolution (user_id, created_at DESC);
