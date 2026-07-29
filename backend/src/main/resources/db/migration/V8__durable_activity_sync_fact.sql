ALTER TABLE app_user
    ADD COLUMN has_successful_activity_sync boolean NOT NULL DEFAULT false;

UPDATE app_user u
SET has_successful_activity_sync = true
WHERE EXISTS (
    SELECT 1
    FROM activity_sync_state s
    WHERE s.user_id = u.user_id
)
OR EXISTS (
    SELECT 1
    FROM processed_activity_sync p
    WHERE p.user_id = u.user_id
)
OR EXISTS (
    SELECT 1
    FROM activity_risk_assessment r
    WHERE r.user_id = u.user_id
);
