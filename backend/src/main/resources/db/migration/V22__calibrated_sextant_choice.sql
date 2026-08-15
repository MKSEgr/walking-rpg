-- Stage chapter-1-v6 without changing the currently active release. The new
-- backend can serve v1-v6 during rollout; activation remains an explicit
-- operator action after every pre-V22 instance has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v6',
    'Первая глава: откалиброванный секстант открывает выбор второго рассвета.',
    '{"contentVersion":"chapter-1-v6","chapterId":"signal-chapter-1","nodeCount":23,"topology":"calibrated-sextant-choice-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
