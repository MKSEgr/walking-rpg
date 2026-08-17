-- Stage chapter-1-v17 without changing the active release. The Steady Step
-- route is activated only after every pre-V33 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v17',
    'Первая глава: «Ровный шаг» открывает Переход первого света.',
    '{"contentVersion":"chapter-1-v17","chapterId":"signal-chapter-1","nodeCount":30,"topology":"steady-step-first-light-causeway-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
