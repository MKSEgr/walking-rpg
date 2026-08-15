ALTER TABLE unique_inventory_item
    ADD COLUMN rarity varchar(16) NOT NULL DEFAULT 'COMMON',
    ADD COLUMN upgraded_at timestamptz,
    ADD CONSTRAINT ck_unique_inventory_item_rarity
        CHECK (rarity IN ('COMMON', 'UNCOMMON', 'RARE')),
    ADD CONSTRAINT ck_unique_inventory_item_upgrade_time
        CHECK (upgraded_at IS NULL OR upgraded_at >= crafted_at);

UPDATE unique_inventory_item
SET rarity = 'UNCOMMON'
WHERE item_id = 'prism-sextant'
  AND version = 1;

CREATE FUNCTION enforce_unique_item_refinement_v21()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.item_id = 'prism-sextant' THEN
        IF NEW.version = 1 THEN
            NEW.rarity := 'UNCOMMON';
            NEW.upgraded_at := NULL;
        ELSIF NEW.version = 2 THEN
            IF NEW.rarity <> 'RARE' OR NEW.upgraded_at IS NULL THEN
                RAISE EXCEPTION
                    'prism-sextant level 2 requires RARE rarity and upgraded_at';
            END IF;
        ELSE
            RAISE EXCEPTION 'unsupported prism-sextant level: %', NEW.version;
        END IF;
    ELSIF NEW.version = 1 AND NEW.upgraded_at IS NULL THEN
        NEW.rarity := 'COMMON';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_unique_item_refinement_v21
BEFORE INSERT OR UPDATE OF item_id, version, rarity, upgraded_at
ON unique_inventory_item
FOR EACH ROW
EXECUTE FUNCTION enforce_unique_item_refinement_v21();

CREATE TABLE processed_item_upgrade_command (
    user_id varchar(128) NOT NULL,
    upgrade_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint char(64) NOT NULL,
    content_version varchar(64) NOT NULL,
    upgrade_version varchar(64) NOT NULL,
    upgrade_name varchar(200) NOT NULL,
    item_instance_id uuid NOT NULL,
    item_id varchar(64) NOT NULL,
    item_name varchar(200) NOT NULL,
    item_description text NOT NULL,
    previous_level bigint NOT NULL CHECK (previous_level > 0),
    result_level bigint NOT NULL CHECK (result_level = previous_level + 1),
    result_rarity varchar(16) NOT NULL CHECK (result_rarity = 'RARE'),
    upgraded_at timestamptz NOT NULL,
    server_time timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, upgrade_id, idempotency_key),
    CONSTRAINT uq_processed_item_upgrade_once
        UNIQUE (user_id, upgrade_id),
    CONSTRAINT ck_processed_item_upgrade_id
        CHECK (btrim(upgrade_id) <> ''),
    CONSTRAINT ck_processed_item_upgrade_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_processed_item_upgrade_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_item_upgrade_content
        CHECK (btrim(content_version) <> ''),
    CONSTRAINT ck_processed_item_upgrade_version
        CHECK (btrim(upgrade_version) <> ''),
    CONSTRAINT ck_processed_item_upgrade_name
        CHECK (btrim(upgrade_name) <> ''),
    CONSTRAINT ck_processed_item_upgrade_item_id
        CHECK (btrim(item_id) <> ''),
    CONSTRAINT ck_processed_item_upgrade_item_name
        CHECK (btrim(item_name) <> ''),
    CONSTRAINT ck_processed_item_upgrade_item_description
        CHECK (btrim(item_description) <> ''),
    CONSTRAINT ck_processed_item_upgrade_time_order
        CHECK (server_time >= upgraded_at),
    CONSTRAINT fk_processed_item_upgrade_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_processed_item_upgrade_owned_item
        FOREIGN KEY (user_id, item_instance_id)
        REFERENCES unique_inventory_item (user_id, item_instance_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_item_upgrade_user_created_at
    ON processed_item_upgrade_command (user_id, created_at DESC);

CREATE TABLE processed_item_upgrade_ingredient (
    user_id varchar(128) NOT NULL,
    upgrade_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    item_id varchar(64) NOT NULL,
    item_name varchar(200) NOT NULL,
    quantity_consumed bigint NOT NULL CHECK (quantity_consumed > 0),
    quantity_after bigint NOT NULL CHECK (quantity_after >= 0),
    inventory_version bigint NOT NULL CHECK (inventory_version > 0),
    PRIMARY KEY (user_id, upgrade_id, idempotency_key, item_id),
    CONSTRAINT ck_processed_item_upgrade_ingredient_id
        CHECK (btrim(item_id) <> ''),
    CONSTRAINT ck_processed_item_upgrade_ingredient_name
        CHECK (btrim(item_name) <> ''),
    CONSTRAINT fk_processed_item_upgrade_ingredient_command
        FOREIGN KEY (user_id, upgrade_id, idempotency_key)
        REFERENCES processed_item_upgrade_command (
            user_id,
            upgrade_id,
            idempotency_key
        )
        ON DELETE CASCADE
);
