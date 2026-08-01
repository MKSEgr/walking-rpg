ALTER TABLE unique_inventory_item
    ADD CONSTRAINT uq_unique_inventory_user_instance
        UNIQUE (user_id, item_instance_id);

CREATE TABLE equipment_slot_state (
    user_id varchar(128) NOT NULL,
    slot_id varchar(64) NOT NULL,
    item_instance_id uuid,
    version bigint NOT NULL CHECK (version >= 0),
    equipped_at timestamptz,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, slot_id),
    CONSTRAINT ck_equipment_slot_id
        CHECK (btrim(slot_id) <> ''),
    CONSTRAINT ck_equipment_slot_item_state
        CHECK (
            (item_instance_id IS NULL AND equipped_at IS NULL)
            OR (item_instance_id IS NOT NULL AND equipped_at IS NOT NULL)
        ),
    CONSTRAINT fk_equipment_slot_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_equipment_slot_owned_item
        FOREIGN KEY (user_id, item_instance_id)
        REFERENCES unique_inventory_item (user_id, item_instance_id)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_equipment_item_single_slot
    ON equipment_slot_state (item_instance_id)
    WHERE item_instance_id IS NOT NULL;

CREATE TABLE processed_equipment_command (
    user_id varchar(128) NOT NULL,
    slot_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint char(64) NOT NULL,
    content_version varchar(64) NOT NULL,
    action varchar(16) NOT NULL,
    changed boolean NOT NULL,
    slot_name varchar(200) NOT NULL,
    slot_description text NOT NULL,
    equipment_version bigint NOT NULL CHECK (equipment_version >= 0),
    item_instance_id uuid,
    item_id varchar(64),
    item_name varchar(200),
    item_description text,
    equipped_at timestamptz,
    server_time timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, slot_id, idempotency_key),
    CONSTRAINT ck_processed_equipment_slot
        CHECK (btrim(slot_id) <> ''),
    CONSTRAINT ck_processed_equipment_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_processed_equipment_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_equipment_content
        CHECK (btrim(content_version) <> ''),
    CONSTRAINT ck_processed_equipment_action
        CHECK (action IN ('EQUIP', 'UNEQUIP')),
    CONSTRAINT ck_processed_equipment_slot_name
        CHECK (btrim(slot_name) <> ''),
    CONSTRAINT ck_processed_equipment_slot_description
        CHECK (btrim(slot_description) <> ''),
    CONSTRAINT ck_processed_equipment_item_snapshot
        CHECK (
            (
                action = 'EQUIP'
                AND item_instance_id IS NOT NULL
                AND item_id IS NOT NULL
                AND btrim(item_id) <> ''
                AND item_name IS NOT NULL
                AND btrim(item_name) <> ''
                AND item_description IS NOT NULL
                AND btrim(item_description) <> ''
                AND equipped_at IS NOT NULL
            )
            OR (
                action = 'UNEQUIP'
                AND item_instance_id IS NULL
                AND item_id IS NULL
                AND item_name IS NULL
                AND item_description IS NULL
                AND equipped_at IS NULL
            )
        ),
    CONSTRAINT ck_processed_equipment_time_order
        CHECK (equipped_at IS NULL OR server_time >= equipped_at),
    CONSTRAINT fk_processed_equipment_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_equipment_user_created_at
    ON processed_equipment_command (user_id, created_at DESC);

-- Deliberately staged inactive. Activate only after every pre-V14 backend
-- instance has drained; otherwise an old instance cannot serve resonance state.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v2',
    'Первая глава: 18 основных узлов и опциональный резонансный маршрут.',
    '{"contentVersion":"chapter-1-v2","chapterId":"signal-chapter-1","nodeCount":19,"topology":"resonance-route-v1"}'::jsonb,
    false,
    'flyway',
    now()
)
ON CONFLICT (content_version) DO UPDATE
SET release_notes = EXCLUDED.release_notes,
    content_json = EXCLUDED.content_json,
    is_active = false,
    created_by = EXCLUDED.created_by,
    created_at = EXCLUDED.created_at;
