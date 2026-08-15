-- Stage chapter-1-v4 without changing the currently active release. The new
-- backend can serve v1-v4 during rollout; activation remains an explicit
-- operator action after every pre-V19 instance has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v4',
    'Первая глава: развилка Сада пустоты через память корней и световую крону.',
    '{"contentVersion":"chapter-1-v4","chapterId":"signal-chapter-1","nodeCount":22,"topology":"void-orchard-fork-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
