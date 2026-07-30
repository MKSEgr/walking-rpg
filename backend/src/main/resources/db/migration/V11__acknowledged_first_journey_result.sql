-- V9 event-resolution writers acquire processed_event_resolution before their
-- AFTER INSERT trigger touches first_journey_milestone. Drain those writers
-- before taking DDL locks in the same order, otherwise a rolling migration can
-- deadlock with the old trigger.
LOCK TABLE processed_event_resolution IN SHARE ROW EXCLUSIVE MODE;

ALTER TABLE first_journey_milestone
    DROP CONSTRAINT ck_first_journey_milestone;

ALTER TABLE first_journey_milestone
    ADD CONSTRAINT ck_first_journey_milestone
        CHECK (milestone IN (
            'JOURNEY_STARTED',
            'FIRST_ACTIVITY_SYNC',
            'FIRST_ENERGY',
            'PET_SELECTED',
            'FIRST_NODE_REACHED',
            'FIRST_EVENT_RESOLVED',
            'FIRST_EVENT_RESULT_ACKNOWLEDGED',
            'ONBOARDING_COMPLETED'
        ));

CREATE FUNCTION require_durable_event_result_to_start_pending()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.handoff_required AND NEW.acknowledged_at IS NOT NULL THEN
        RAISE EXCEPTION
            'durable event result must start pending'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_require_durable_event_result_to_start_pending
BEFORE INSERT ON processed_event_resolution
FOR EACH ROW
EXECUTE FUNCTION require_durable_event_result_to_start_pending();

CREATE OR REPLACE FUNCTION capture_event_first_journey_milestones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM record_first_journey_milestone(
        NEW.user_id,
        'FIRST_EVENT_RESOLVED',
        NEW.server_time,
        jsonb_build_object(
            'eventId', NEW.event_id,
            'choiceId', NEW.choice_id
        )
    );

    IF NEW.acknowledged_at IS NOT NULL THEN
        INSERT INTO first_journey_milestone (
            user_id,
            milestone,
            occurred_at,
            source,
            attributes,
            recorded_at
        ) VALUES (
            NEW.user_id,
            'FIRST_EVENT_RESULT_ACKNOWLEDGED',
            NEW.acknowledged_at,
            'BACKFILLED',
            jsonb_build_object(
                'receiptId', NEW.receipt_id,
                'eventId', NEW.event_id,
                'handoffRequired', false,
                'deliveryMode', 'LEGACY_AUTO_ACK'
            ),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (user_id, milestone) DO NOTHING;
    END IF;

    PERFORM record_first_journey_completion_if_ready(NEW.user_id);
    RETURN NEW;
END
$$;

CREATE FUNCTION capture_event_result_acknowledgement_milestone()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM record_first_journey_milestone(
        NEW.user_id,
        'FIRST_EVENT_RESULT_ACKNOWLEDGED',
        NEW.acknowledged_at,
        jsonb_build_object(
            'receiptId', NEW.receipt_id,
            'eventId', NEW.event_id,
            'handoffRequired', NEW.handoff_required,
            'deliveryMode', 'DURABLE_ACK'
        )
    );
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_event_result_acknowledgement_milestone
AFTER UPDATE OF acknowledged_at ON processed_event_resolution
FOR EACH ROW
WHEN (
    OLD.acknowledged_at IS NULL
    AND NEW.acknowledged_at IS NOT NULL
)
EXECUTE FUNCTION capture_event_result_acknowledgement_milestone();

CREATE FUNCTION enforce_event_result_acknowledgement_immutability()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.handoff_required IS DISTINCT FROM OLD.handoff_required THEN
        RAISE EXCEPTION
            'event result delivery mode is immutable'
            USING ERRCODE = '23514';
    END IF;
    IF OLD.acknowledged_at IS NOT NULL
       AND NEW.acknowledged_at IS DISTINCT FROM OLD.acknowledged_at THEN
        RAISE EXCEPTION
            'processed event result acknowledgement is immutable'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_event_result_acknowledgement_immutability
BEFORE UPDATE OF acknowledged_at, handoff_required
ON processed_event_resolution
FOR EACH ROW
EXECUTE FUNCTION enforce_event_result_acknowledgement_immutability();

INSERT INTO first_journey_milestone (
    user_id,
    milestone,
    occurred_at,
    source,
    attributes,
    recorded_at
)
SELECT DISTINCT ON (resolution.user_id)
       resolution.user_id,
       'FIRST_EVENT_RESULT_ACKNOWLEDGED',
       resolution.acknowledged_at,
       'BACKFILLED',
       jsonb_build_object(
           'migration', 'V11',
           'receiptId', resolution.receipt_id,
           'eventId', resolution.event_id,
           'handoffRequired', resolution.handoff_required,
           'deliveryMode', CASE
               WHEN resolution.handoff_required THEN 'DURABLE_ACK'
               ELSE 'LEGACY_AUTO_ACK'
           END
       ),
       CURRENT_TIMESTAMP
FROM processed_event_resolution resolution
WHERE resolution.acknowledged_at IS NOT NULL
ORDER BY
    resolution.user_id,
    resolution.acknowledged_at,
    resolution.server_time,
    resolution.receipt_id
ON CONFLICT (user_id, milestone) DO NOTHING;
