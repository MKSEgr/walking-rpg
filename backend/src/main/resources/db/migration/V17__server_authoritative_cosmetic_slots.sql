CREATE TABLE platform_cosmetic_slot_state (
    user_id varchar(128) NOT NULL,
    slot varchar(32) NOT NULL,
    cosmetic_id varchar(128) NOT NULL,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
    equipped_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, slot),
    CONSTRAINT uq_platform_cosmetic_slot_item
        UNIQUE (user_id, cosmetic_id),
    CONSTRAINT ck_platform_cosmetic_slot
        CHECK (slot IN ('PILOT', 'PET', 'PROFILE')),
    CONSTRAINT ck_platform_cosmetic_id
        CHECK (btrim(cosmetic_id) <> ''),
    CONSTRAINT ck_platform_cosmetic_timestamps
        CHECK (updated_at >= equipped_at),
    CONSTRAINT fk_platform_cosmetic_slot_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

-- Preserve the one cosmetic selected by pre-V17 instances. The catalog owns
-- the slot mapping; unknown legacy IDs stay only in the compatibility field
-- until a server version that knows that catalog item can materialize them.
INSERT INTO platform_cosmetic_slot_state (
    user_id,
    slot,
    cosmetic_id,
    version,
    equipped_at,
    updated_at
)
SELECT state.user_id,
       catalog.slot,
       catalog.cosmetic_id,
       1,
       state.updated_at,
       state.updated_at
FROM roadmap_user_state state
JOIN (VALUES
    ('pilot-scarf', 'PILOT'),
    ('spark-halo', 'PET'),
    ('trail-banner', 'PROFILE'),
    ('dawn-frame', 'PROFILE')
) AS catalog(cosmetic_id, slot)
  ON catalog.cosmetic_id = state.state_json ->> 'activeCosmeticId';

CREATE INDEX ix_platform_cosmetic_slot_user_updated_at
    ON platform_cosmetic_slot_state (user_id, updated_at DESC);
