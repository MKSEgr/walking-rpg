CREATE TABLE first_journey_milestone (
    user_id varchar(128) NOT NULL,
    milestone varchar(64) NOT NULL,
    occurred_at timestamptz NOT NULL,
    source varchar(32) NOT NULL,
    attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
    recorded_at timestamptz NOT NULL,
    PRIMARY KEY (user_id, milestone),
    CONSTRAINT ck_first_journey_milestone
        CHECK (milestone IN (
            'JOURNEY_STARTED',
            'FIRST_ACTIVITY_SYNC',
            'FIRST_ENERGY',
            'PET_SELECTED',
            'FIRST_NODE_REACHED',
            'FIRST_EVENT_RESOLVED',
            'ONBOARDING_COMPLETED'
        )),
    CONSTRAINT ck_first_journey_source
        CHECK (source IN ('AUTHORITATIVE', 'BACKFILLED')),
    CONSTRAINT ck_first_journey_attributes_object
        CHECK (jsonb_typeof(attributes) = 'object'),
    CONSTRAINT fk_first_journey_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id)
        ON DELETE CASCADE
);

CREATE INDEX ix_first_journey_milestone_occurred_at
    ON first_journey_milestone (milestone, occurred_at, user_id);

CREATE INDEX ix_first_journey_user_occurred_at
    ON first_journey_milestone (user_id, occurred_at, milestone);

CREATE FUNCTION record_first_journey_milestone(
    milestone_user_id varchar,
    milestone_name varchar,
    milestone_occurred_at timestamptz,
    milestone_attributes jsonb
) RETURNS void
LANGUAGE sql
AS $$
    INSERT INTO first_journey_milestone (
        user_id,
        milestone,
        occurred_at,
        source,
        attributes,
        recorded_at
    ) VALUES (
        milestone_user_id,
        milestone_name,
        milestone_occurred_at,
        'AUTHORITATIVE',
        COALESCE(milestone_attributes, '{}'::jsonb),
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (user_id, milestone) DO NOTHING
$$;

CREATE FUNCTION record_first_journey_completion_if_ready(
    completion_user_id varchar
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    onboarding_completed_at timestamptz;
    onboarding_state_version jsonb;
    final_fact_at timestamptz;
    prerequisite_count bigint;
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            length(completion_user_id)::text || ':' || completion_user_id,
            23
        )
    );

    SELECT command.created_at,
           command.response_json #> '{snapshot,stateVersion}'
    INTO onboarding_completed_at, onboarding_state_version
    FROM processed_roadmap_command command
    WHERE command.user_id = completion_user_id
      AND COALESCE(
          (
              command.response_json
              #>> '{snapshot,userState,onboardingComplete}'
          )::boolean,
          false
      )
    ORDER BY command.created_at, command.command_type, command.idempotency_key
    LIMIT 1;

    IF onboarding_completed_at IS NULL THEN
        RETURN;
    END IF;

    SELECT max(milestone.occurred_at),
           count(*)
    INTO final_fact_at, prerequisite_count
    FROM first_journey_milestone milestone
    WHERE milestone.user_id = completion_user_id
      AND milestone.milestone IN (
          'JOURNEY_STARTED',
          'FIRST_ACTIVITY_SYNC',
          'FIRST_ENERGY',
          'PET_SELECTED',
          'FIRST_NODE_REACHED',
          'FIRST_EVENT_RESOLVED'
      );

    IF prerequisite_count <> 6 THEN
        RETURN;
    END IF;

    PERFORM record_first_journey_milestone(
        completion_user_id,
        'ONBOARDING_COMPLETED',
        GREATEST(onboarding_completed_at, final_fact_at),
        jsonb_build_object('stateVersion', onboarding_state_version)
    );
END
$$;

CREATE FUNCTION capture_roadmap_first_journey_milestones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.command_type = 'COMPLETE_ONBOARDING_STEP'
       AND NEW.response_json #> '{snapshot,userState,completedOnboardingSteps}'
           @> '["welcome"]'::jsonb THEN
        PERFORM record_first_journey_milestone(
            NEW.user_id,
            'JOURNEY_STARTED',
            NEW.created_at,
            jsonb_build_object('commandType', NEW.command_type)
        );
    END IF;

    IF NEW.command_type = 'SELECT_PET' THEN
        PERFORM record_first_journey_milestone(
            NEW.user_id,
            'PET_SELECTED',
            NEW.created_at,
            jsonb_build_object(
                'petId',
                NEW.response_json #>> '{snapshot,userState,activePetId}'
            )
        );
    END IF;

    PERFORM record_first_journey_completion_if_ready(NEW.user_id);

    RETURN NEW;
END
$$;

CREATE TRIGGER trg_roadmap_first_journey_milestones
AFTER INSERT ON processed_roadmap_command
FOR EACH ROW
EXECUTE FUNCTION capture_roadmap_first_journey_milestones();

CREATE FUNCTION capture_activity_first_journey_milestones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM record_first_journey_milestone(
        NEW.user_id,
        'FIRST_ACTIVITY_SYNC',
        NEW.server_time,
        jsonb_build_object(
            'energyGranted', NEW.energy_granted
        )
    );
    PERFORM record_first_journey_completion_if_ready(NEW.user_id);
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_activity_first_journey_milestones
AFTER INSERT ON processed_activity_sync
FOR EACH ROW
EXECUTE FUNCTION capture_activity_first_journey_milestones();

CREATE FUNCTION capture_energy_first_journey_milestones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.currency_code = 'ENERGY'
       AND NEW.amount > 0
       AND NEW.reason_code = 'ACTIVITY_STEPS'
       AND NEW.source_type = 'ACTIVITY_SYNC' THEN
        PERFORM record_first_journey_milestone(
            NEW.user_id,
            'FIRST_ENERGY',
            NEW.created_at,
            jsonb_build_object('energyGranted', NEW.amount)
        );
        PERFORM record_first_journey_completion_if_ready(NEW.user_id);
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_energy_first_journey_milestones
AFTER INSERT ON economy_ledger
FOR EACH ROW
EXECUTE FUNCTION capture_energy_first_journey_milestones();

CREATE FUNCTION capture_node_first_journey_milestones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.event_id IS NOT NULL THEN
        PERFORM record_first_journey_milestone(
            NEW.user_id,
            'FIRST_NODE_REACHED',
            NEW.server_time,
            jsonb_build_object(
                'nodeId', NEW.current_node_id,
                'eventId', NEW.event_id
            )
        );
        PERFORM record_first_journey_completion_if_ready(NEW.user_id);
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_node_first_journey_milestones
AFTER INSERT ON processed_expedition_advance
FOR EACH ROW
EXECUTE FUNCTION capture_node_first_journey_milestones();

CREATE FUNCTION capture_event_first_journey_milestones()
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
    PERFORM record_first_journey_completion_if_ready(NEW.user_id);
    RETURN NEW;
END
$$;

CREATE TRIGGER trg_event_first_journey_milestones
AFTER INSERT ON processed_event_resolution
FOR EACH ROW
EXECUTE FUNCTION capture_event_first_journey_milestones();

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT DISTINCT ON (command.user_id)
       command.user_id,
       'JOURNEY_STARTED',
       command.created_at,
       'BACKFILLED',
       '{"migration":"V9"}'::jsonb,
       CURRENT_TIMESTAMP
FROM processed_roadmap_command command
WHERE command.command_type = 'COMPLETE_ONBOARDING_STEP'
  AND command.response_json #> '{snapshot,userState,completedOnboardingSteps}'
      @> '["welcome"]'::jsonb
ORDER BY command.user_id, command.created_at;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT state.user_id,
       'JOURNEY_STARTED',
       state.created_at,
       'BACKFILLED',
       '{"migration":"V9","precision":"state-created-at"}'::jsonb,
       CURRENT_TIMESTAMP
FROM roadmap_user_state state
WHERE state.state_json -> 'completedOnboardingSteps' @> '["welcome"]'::jsonb
ON CONFLICT (user_id, milestone) DO NOTHING;

WITH activity_evidence AS (
    SELECT user_id, server_time AS occurred_at
    FROM processed_activity_sync
    UNION ALL
    SELECT user_id, created_at
    FROM activity_risk_assessment
    UNION ALL
    SELECT user_id, updated_at
    FROM activity_sync_state
),
first_activity AS (
    SELECT user_id, min(occurred_at) AS occurred_at
    FROM activity_evidence
    GROUP BY user_id
)
INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT user_id,
       'FIRST_ACTIVITY_SYNC',
       occurred_at,
       'BACKFILLED',
       '{"migration":"V9"}'::jsonb,
       CURRENT_TIMESTAMP
FROM first_activity;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT user_id,
       'FIRST_ACTIVITY_SYNC',
       last_seen_at,
       'BACKFILLED',
       '{"migration":"V9","precision":"last-seen-at"}'::jsonb,
       CURRENT_TIMESTAMP
FROM app_user
WHERE has_successful_activity_sync
ON CONFLICT (user_id, milestone) DO NOTHING;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT DISTINCT ON (ledger.user_id)
       ledger.user_id,
       'FIRST_ENERGY',
       ledger.created_at,
       'BACKFILLED',
       jsonb_build_object(
           'migration', 'V9',
           'energyGranted', ledger.amount
       ),
       CURRENT_TIMESTAMP
FROM economy_ledger ledger
WHERE ledger.currency_code = 'ENERGY'
  AND ledger.amount > 0
  AND ledger.reason_code = 'ACTIVITY_STEPS'
  AND ledger.source_type = 'ACTIVITY_SYNC'
ORDER BY ledger.user_id, ledger.created_at, ledger.ledger_entry_id;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT DISTINCT ON (command.user_id)
       command.user_id,
       'PET_SELECTED',
       command.created_at,
       'BACKFILLED',
       jsonb_build_object(
           'migration', 'V9',
           'petId', command.response_json #>> '{snapshot,userState,activePetId}'
       ),
       CURRENT_TIMESTAMP
FROM processed_roadmap_command command
WHERE command.command_type = 'SELECT_PET'
ORDER BY command.user_id, command.created_at;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT state.user_id,
       'PET_SELECTED',
       state.updated_at,
       'BACKFILLED',
       '{"migration":"V9","precision":"state-updated-at"}'::jsonb,
       CURRENT_TIMESTAMP
FROM roadmap_user_state state
WHERE state.state_json -> 'completedOnboardingSteps'
      @> '["pet-selection"]'::jsonb
ON CONFLICT (user_id, milestone) DO NOTHING;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT DISTINCT ON (operation.user_id)
       operation.user_id,
       'FIRST_NODE_REACHED',
       operation.server_time,
       'BACKFILLED',
       jsonb_build_object(
           'migration', 'V9',
           'nodeId', operation.current_node_id,
           'eventId', operation.event_id
       ),
       CURRENT_TIMESTAMP
FROM processed_expedition_advance operation
WHERE operation.event_id IS NOT NULL
ORDER BY operation.user_id, operation.server_time, operation.idempotency_key;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT state.user_id,
       'FIRST_NODE_REACHED',
       state.updated_at,
       'BACKFILLED',
       '{"migration":"V9","precision":"state-updated-at"}'::jsonb,
       CURRENT_TIMESTAMP
FROM roadmap_user_state state
WHERE state.state_json -> 'completedOnboardingSteps'
      @> '["first-expedition"]'::jsonb
ON CONFLICT (user_id, milestone) DO NOTHING;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT DISTINCT ON (operation.user_id)
       operation.user_id,
       'FIRST_EVENT_RESOLVED',
       operation.server_time,
       'BACKFILLED',
       jsonb_build_object(
           'migration', 'V9',
           'eventId', operation.event_id,
           'choiceId', operation.choice_id
       ),
       CURRENT_TIMESTAMP
FROM processed_event_resolution operation
ORDER BY operation.user_id, operation.server_time, operation.idempotency_key;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT state.user_id,
       'FIRST_EVENT_RESOLVED',
       state.updated_at,
       'BACKFILLED',
       '{"migration":"V9","precision":"state-updated-at"}'::jsonb,
       CURRENT_TIMESTAMP
FROM roadmap_user_state state
WHERE state.state_json -> 'completedOnboardingSteps' @> '["first-event"]'::jsonb
ON CONFLICT (user_id, milestone) DO NOTHING;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT DISTINCT ON (command.user_id)
       command.user_id,
       'ONBOARDING_COMPLETED',
       command.created_at,
       'BACKFILLED',
       '{"migration":"V9"}'::jsonb,
       CURRENT_TIMESTAMP
FROM processed_roadmap_command command
WHERE COALESCE(
    (command.response_json #>> '{snapshot,userState,onboardingComplete}')::boolean,
    false
)
ORDER BY command.user_id, command.created_at;

INSERT INTO first_journey_milestone (
    user_id, milestone, occurred_at, source, attributes, recorded_at
)
SELECT state.user_id,
       'ONBOARDING_COMPLETED',
       state.updated_at,
       'BACKFILLED',
       '{"migration":"V9","precision":"state-updated-at"}'::jsonb,
       CURRENT_TIMESTAMP
FROM roadmap_user_state state
WHERE state.state_json -> 'completedOnboardingSteps' @>
      '["welcome","health-permission","first-sync","pet-selection","first-expedition","first-event"]'::jsonb
ON CONFLICT (user_id, milestone) DO NOTHING;
