-- Stage chapter-1-v7 without changing the currently active release. The new
-- backend can serve v1-v7 during rollout; activation remains an explicit
-- operator action after every pre-V23 instance has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v7',
    'Первая глава: откалиброванный секстант открывает эпилог второго рассвета.',
    '{"contentVersion":"chapter-1-v7","chapterId":"signal-chapter-1","nodeCount":24,"topology":"second-dawn-epilogue-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
