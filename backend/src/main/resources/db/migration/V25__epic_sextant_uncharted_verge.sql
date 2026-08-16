-- Stage chapter-1-v9 without changing the active release. The additive route
-- is served only after every pre-V25 backend instance has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v9',
    'Первая глава: EPIC-секстант открывает неизведанный рубеж за вторым рассветом.',
    '{"contentVersion":"chapter-1-v9","chapterId":"signal-chapter-1","nodeCount":25,"topology":"epic-sextant-uncharted-verge-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
