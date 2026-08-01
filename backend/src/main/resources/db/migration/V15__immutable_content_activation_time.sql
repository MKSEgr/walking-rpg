ALTER TABLE content_release
    ADD COLUMN IF NOT EXISTS activated_at timestamptz;

-- chapter-1-v1 is the only release that V14 guarantees was already active
-- before the staged resonance route existed. Its timestamp is compatibility
-- metadata; the compass funnel never uses it as a route baseline.
UPDATE content_release
SET activated_at = created_at
WHERE content_version = 'chapter-1-v1'
  AND activated_at IS NULL;

-- A V14 backend could activate and then republish chapter-1-v2 before this
-- migration. In that case created_at is only the latest publish timestamp, so
-- silently copying it would corrupt historical funnel latency. The operator
-- must pre-create activated_at and seed the verified first activation time
-- before Flyway runs V15. The untouched staged V14 row remains safely NULL.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM content_release
        WHERE content_version = 'chapter-1-v2'
          AND activated_at IS NULL
          AND (
              is_active
              OR created_by IS DISTINCT FROM 'flyway'
          )
    ) THEN
        RAISE EXCEPTION
            'V15 requires explicit chapter-1-v2 first activation timestamp'
            USING HINT =
                'Seed content_release.activated_at from verified rollout evidence before rerunning Flyway; do not copy mutable created_at.';
    END IF;
END;
$$;

ALTER TABLE content_release
    ADD CONSTRAINT ck_content_release_active_timestamp
        CHECK (NOT is_active OR activated_at IS NOT NULL);

CREATE FUNCTION reject_content_release_activation_rewrite()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.activated_at IS NOT NULL
       AND NEW.activated_at IS DISTINCT FROM OLD.activated_at THEN
        RAISE EXCEPTION 'content_release.activated_at is immutable after first activation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_content_release_activation_immutable
BEFORE UPDATE OF activated_at ON content_release
FOR EACH ROW
EXECUTE FUNCTION reject_content_release_activation_rewrite();
