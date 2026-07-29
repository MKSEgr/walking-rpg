ALTER TABLE processed_event_resolution
    ADD COLUMN receipt_id uuid DEFAULT gen_random_uuid(),
    ADD COLUMN handoff_required boolean NOT NULL DEFAULT false,
    ADD COLUMN next_node_id varchar(64),
    ADD COLUMN next_node_name varchar(200),
    ADD COLUMN acknowledged_at timestamptz;

CREATE FUNCTION normalize_legacy_event_result_handoff()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT NEW.handoff_required AND NEW.acknowledged_at IS NULL THEN
        NEW.acknowledged_at := NEW.server_time;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_normalize_legacy_event_result_handoff
BEFORE INSERT ON processed_event_resolution
FOR EACH ROW
EXECUTE FUNCTION normalize_legacy_event_result_handoff();

-- Resolutions created before this feature were already consumed through the
-- transient response/UI. Backfill them as acknowledged instead of resurfacing
-- old rewards after an upgrade.
UPDATE processed_event_resolution
SET acknowledged_at = server_time;

ALTER TABLE processed_event_resolution
    ALTER COLUMN receipt_id SET NOT NULL,
    ADD CONSTRAINT uq_processed_event_result_receipt
        UNIQUE (receipt_id),
    ADD CONSTRAINT ck_processed_event_result_next_node
        CHECK (
            (next_node_id IS NULL AND next_node_name IS NULL)
            OR (
                next_node_id IS NOT NULL
                AND btrim(next_node_id) <> ''
                AND next_node_name IS NOT NULL
                AND btrim(next_node_name) <> ''
            )
        ),
    ADD CONSTRAINT ck_processed_event_result_acknowledged_at
        CHECK (
            acknowledged_at IS NULL
            OR acknowledged_at >= server_time
        ),
    ADD CONSTRAINT ck_processed_event_result_handoff
        CHECK (
            handoff_required
            OR acknowledged_at IS NOT NULL
        );

CREATE UNIQUE INDEX uq_processed_event_result_pending
    ON processed_event_resolution (user_id, expedition_id)
    WHERE handoff_required
      AND acknowledged_at IS NULL;
