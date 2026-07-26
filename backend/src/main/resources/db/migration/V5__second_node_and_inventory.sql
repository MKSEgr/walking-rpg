ALTER TABLE processed_event_resolution
    DROP CONSTRAINT ck_processed_event_expedition_status;

ALTER TABLE processed_event_resolution
    ADD CONSTRAINT ck_processed_event_expedition_status
        CHECK (expedition_status IN ('IN_PROGRESS', 'COMPLETED'));

ALTER TABLE processed_event_resolution
    ADD COLUMN material_item_id varchar(64),
    ADD COLUMN material_item_name varchar(200),
    ADD COLUMN material_item_description text,
    ADD COLUMN material_quantity_gained bigint,
    ADD COLUMN material_quantity_after bigint,
    ADD COLUMN material_version bigint;

ALTER TABLE processed_event_resolution
    ADD CONSTRAINT ck_processed_event_material_reward
        CHECK (
            (
                material_item_id IS NULL
                AND material_item_name IS NULL
                AND material_item_description IS NULL
                AND material_quantity_gained IS NULL
                AND material_quantity_after IS NULL
                AND material_version IS NULL
            )
            OR (
                material_item_id IS NOT NULL
                AND btrim(material_item_id) <> ''
                AND material_item_name IS NOT NULL
                AND btrim(material_item_name) <> ''
                AND material_item_description IS NOT NULL
                AND btrim(material_item_description) <> ''
                AND material_quantity_gained IS NOT NULL
                AND material_quantity_gained > 0
                AND material_quantity_after IS NOT NULL
                AND material_quantity_after >= material_quantity_gained
                AND material_version IS NOT NULL
                AND material_version > 0
            )
        );

CREATE TABLE inventory_stack (
    user_id varchar(128) NOT NULL,
    item_id varchar(64) NOT NULL,
    quantity bigint NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, item_id),
    CONSTRAINT ck_inventory_stack_item_id
        CHECK (btrim(item_id) <> ''),
    CONSTRAINT fk_inventory_stack_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE inventory_ledger (
    ledger_entry_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id varchar(128) NOT NULL,
    item_id varchar(64) NOT NULL,
    quantity_delta bigint NOT NULL CHECK (quantity_delta > 0),
    quantity_after bigint NOT NULL CHECK (quantity_after >= quantity_delta),
    inventory_version bigint NOT NULL CHECK (inventory_version > 0),
    reason_code varchar(64) NOT NULL,
    source_type varchar(64) NOT NULL,
    source_key varchar(300) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_inventory_ledger_item_id
        CHECK (btrim(item_id) <> ''),
    CONSTRAINT ck_inventory_ledger_reason
        CHECK (btrim(reason_code) <> ''),
    CONSTRAINT ck_inventory_ledger_source_type
        CHECK (btrim(source_type) <> ''),
    CONSTRAINT ck_inventory_ledger_source_key
        CHECK (btrim(source_key) <> ''),
    CONSTRAINT uq_inventory_ledger_source
        UNIQUE (user_id, source_type, source_key),
    CONSTRAINT fk_inventory_ledger_stack
        FOREIGN KEY (user_id, item_id)
        REFERENCES inventory_stack (user_id, item_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_inventory_ledger_user_created_at
    ON inventory_ledger (user_id, created_at DESC);

-- Existing users who completed the first starter node continue at the second node.
-- The original event resolution remains in processed_event_resolution as immutable history.
UPDATE expedition_progress progress
SET current_node_id = 'lumen-gate',
    progress_energy = 0,
    required_energy = 45,
    status = 'IN_PROGRESS',
    unlocked_event_id = NULL,
    version = progress.version + 1,
    updated_at = now()
WHERE progress.expedition_id = 'starter-expedition-v1'
  AND progress.current_node_id = 'outer-beacon'
  AND progress.status = 'COMPLETED'
  AND progress.unlocked_event_id = 'signal-source-v1'
  AND EXISTS (
      SELECT 1
      FROM processed_event_resolution resolution
      WHERE resolution.user_id = progress.user_id
        AND resolution.expedition_id = progress.expedition_id
        AND resolution.event_id = 'signal-source-v1'
  );
