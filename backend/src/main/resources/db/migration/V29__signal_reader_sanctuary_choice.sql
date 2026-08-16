-- Stage chapter-1-v13 without changing the active release. The skill-gated
-- sanctuary choice is served only after every pre-V29 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v13',
    'Первая глава: навык «Чтение сигналов» открывает скрытый исход Святилища созвездий.',
    '{"contentVersion":"chapter-1-v13","chapterId":"signal-chapter-1","nodeCount":26,"topology":"signal-reader-sanctuary-choice-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
