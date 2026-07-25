CREATE TABLE economy_wallet (
    user_id varchar(128) NOT NULL,
    currency_code varchar(32) NOT NULL,
    balance bigint NOT NULL DEFAULT 0 CHECK (balance >= 0),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, currency_code),
    CONSTRAINT ck_economy_wallet_currency
        CHECK (btrim(currency_code) <> ''),
    CONSTRAINT fk_economy_wallet_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE TABLE economy_ledger (
    ledger_entry_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id varchar(128) NOT NULL,
    currency_code varchar(32) NOT NULL,
    amount bigint NOT NULL CHECK (amount <> 0),
    balance_after bigint NOT NULL CHECK (balance_after >= 0),
    wallet_version bigint NOT NULL CHECK (wallet_version > 0),
    reason_code varchar(64) NOT NULL,
    source_type varchar(64) NOT NULL,
    source_key varchar(300) NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_economy_ledger_reason
        CHECK (btrim(reason_code) <> ''),
    CONSTRAINT ck_economy_ledger_source_type
        CHECK (btrim(source_type) <> ''),
    CONSTRAINT ck_economy_ledger_source_key
        CHECK (btrim(source_key) <> ''),
    CONSTRAINT uq_economy_ledger_source
        UNIQUE (user_id, currency_code, source_type, source_key),
    CONSTRAINT fk_economy_ledger_wallet
        FOREIGN KEY (user_id, currency_code)
        REFERENCES economy_wallet (user_id, currency_code)
        ON DELETE CASCADE
);

INSERT INTO economy_wallet (
    user_id,
    currency_code,
    balance,
    version,
    created_at,
    updated_at
)
SELECT u.user_id,
       'ENERGY',
       COALESCE(SUM(p.energy_granted), 0),
       COUNT(*) FILTER (WHERE p.energy_granted > 0),
       u.created_at,
       GREATEST(
           u.last_seen_at,
           COALESCE(MAX(p.created_at), u.last_seen_at)
       )
FROM app_user u
LEFT JOIN processed_activity_sync p ON p.user_id = u.user_id
GROUP BY u.user_id, u.created_at, u.last_seen_at;

ALTER TABLE processed_activity_sync
    ADD COLUMN energy_balance_after bigint,
    ADD COLUMN economy_version bigint;

WITH snapshots AS (
    SELECT user_id,
           device_id,
           idempotency_key,
           SUM(energy_granted) OVER activity_order AS energy_balance_after,
           COUNT(*) FILTER (WHERE energy_granted > 0)
               OVER activity_order AS economy_version
    FROM processed_activity_sync
    WINDOW activity_order AS (
        PARTITION BY user_id
        ORDER BY server_time, created_at, device_id, idempotency_key
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
)
UPDATE processed_activity_sync p
SET energy_balance_after = s.energy_balance_after,
    economy_version = s.economy_version
FROM snapshots s
WHERE p.user_id = s.user_id
  AND p.device_id = s.device_id
  AND p.idempotency_key = s.idempotency_key;

ALTER TABLE processed_activity_sync
    ALTER COLUMN energy_balance_after SET NOT NULL,
    ALTER COLUMN economy_version SET NOT NULL,
    ADD CONSTRAINT ck_processed_activity_sync_energy_balance
        CHECK (energy_balance_after >= 0),
    ADD CONSTRAINT ck_processed_activity_sync_economy_version
        CHECK (economy_version >= 0);

INSERT INTO economy_ledger (
    ledger_entry_id,
    user_id,
    currency_code,
    amount,
    balance_after,
    wallet_version,
    reason_code,
    source_type,
    source_key,
    created_at
)
SELECT gen_random_uuid(),
       p.user_id,
       'ENERGY',
       p.energy_granted,
       p.energy_balance_after,
       p.economy_version,
       'ACTIVITY_STEPS',
       'ACTIVITY_SYNC',
       char_length(p.device_id)::text
           || ':' || p.device_id
           || ':' || p.idempotency_key,
       p.created_at
FROM processed_activity_sync p
WHERE p.energy_granted > 0;

CREATE INDEX ix_economy_ledger_user_created_at
    ON economy_ledger (user_id, created_at DESC);
