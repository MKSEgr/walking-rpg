CREATE TABLE account_deletion_receipt (
    subject_hash char(64) PRIMARY KEY,
    receipt_id uuid NOT NULL UNIQUE,
    request_key_hash char(64) NOT NULL,
    requested_at timestamptz NOT NULL,
    completed_at timestamptz NOT NULL,
    CONSTRAINT ck_account_deletion_subject_hash
        CHECK (subject_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_account_deletion_request_key_hash
        CHECK (request_key_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_account_deletion_completed_after_request
        CHECK (completed_at >= requested_at)
);

CREATE INDEX ix_account_deletion_completed_at
    ON account_deletion_receipt (completed_at);
