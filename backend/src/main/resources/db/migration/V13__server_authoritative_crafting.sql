ALTER TABLE inventory_ledger
    DROP CONSTRAINT inventory_ledger_quantity_delta_check;

ALTER TABLE inventory_ledger
    DROP CONSTRAINT inventory_ledger_check;

ALTER TABLE inventory_ledger
    ADD CONSTRAINT ck_inventory_ledger_quantity_delta_non_zero
        CHECK (quantity_delta <> 0),
    ADD CONSTRAINT ck_inventory_ledger_quantity_after_non_negative
        CHECK (quantity_after >= 0);

CREATE TABLE unique_inventory_item (
    item_instance_id uuid PRIMARY KEY,
    user_id varchar(128) NOT NULL,
    item_id varchar(64) NOT NULL,
    recipe_id varchar(64) NOT NULL,
    recipe_version varchar(64) NOT NULL,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
    crafted_at timestamptz NOT NULL,
    CONSTRAINT ck_unique_inventory_item_id
        CHECK (btrim(item_id) <> ''),
    CONSTRAINT ck_unique_inventory_recipe_id
        CHECK (btrim(recipe_id) <> ''),
    CONSTRAINT ck_unique_inventory_recipe_version
        CHECK (btrim(recipe_version) <> ''),
    CONSTRAINT uq_unique_inventory_user_item
        UNIQUE (user_id, item_id),
    CONSTRAINT uq_unique_inventory_user_recipe
        UNIQUE (user_id, recipe_id),
    CONSTRAINT fk_unique_inventory_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_unique_inventory_user_crafted_at
    ON unique_inventory_item (user_id, crafted_at DESC);

CREATE TABLE processed_crafting_command (
    user_id varchar(128) NOT NULL,
    recipe_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    request_fingerprint char(64) NOT NULL,
    content_version varchar(64) NOT NULL,
    recipe_version varchar(64) NOT NULL,
    recipe_name varchar(200) NOT NULL,
    item_instance_id uuid NOT NULL,
    result_item_id varchar(64) NOT NULL,
    result_item_name varchar(200) NOT NULL,
    result_item_description text NOT NULL,
    result_item_version bigint NOT NULL CHECK (result_item_version > 0),
    crafted_at timestamptz NOT NULL,
    server_time timestamptz NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, recipe_id, idempotency_key),
    CONSTRAINT uq_processed_crafting_item_instance
        UNIQUE (item_instance_id),
    CONSTRAINT ck_processed_crafting_recipe_id
        CHECK (btrim(recipe_id) <> ''),
    CONSTRAINT ck_processed_crafting_key
        CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT ck_processed_crafting_fingerprint
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_processed_crafting_content_version
        CHECK (btrim(content_version) <> ''),
    CONSTRAINT ck_processed_crafting_recipe_version
        CHECK (btrim(recipe_version) <> ''),
    CONSTRAINT ck_processed_crafting_recipe_name
        CHECK (btrim(recipe_name) <> ''),
    CONSTRAINT ck_processed_crafting_result_item_id
        CHECK (btrim(result_item_id) <> ''),
    CONSTRAINT ck_processed_crafting_result_item_name
        CHECK (btrim(result_item_name) <> ''),
    CONSTRAINT ck_processed_crafting_result_description
        CHECK (btrim(result_item_description) <> ''),
    CONSTRAINT ck_processed_crafting_time_order
        CHECK (server_time >= crafted_at),
    CONSTRAINT fk_processed_crafting_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_processed_crafting_user_created_at
    ON processed_crafting_command (user_id, created_at DESC);

CREATE TABLE processed_crafting_ingredient (
    user_id varchar(128) NOT NULL,
    recipe_id varchar(64) NOT NULL,
    idempotency_key varchar(128) NOT NULL,
    item_id varchar(64) NOT NULL,
    item_name varchar(200) NOT NULL,
    quantity_consumed bigint NOT NULL CHECK (quantity_consumed > 0),
    quantity_after bigint NOT NULL CHECK (quantity_after >= 0),
    inventory_version bigint NOT NULL CHECK (inventory_version > 0),
    PRIMARY KEY (user_id, recipe_id, idempotency_key, item_id),
    CONSTRAINT ck_processed_crafting_ingredient_item_id
        CHECK (btrim(item_id) <> ''),
    CONSTRAINT ck_processed_crafting_ingredient_item_name
        CHECK (btrim(item_name) <> ''),
    CONSTRAINT fk_processed_crafting_ingredient_command
        FOREIGN KEY (user_id, recipe_id, idempotency_key)
        REFERENCES processed_crafting_command (
            user_id,
            recipe_id,
            idempotency_key
        )
        ON DELETE CASCADE
);
