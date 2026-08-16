-- Stage chapter-1-v15 without changing the active release. The Trail Memory
-- route is activated only after every pre-V31 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v15',
    'Первая глава: «Память маршрута» восстанавливает путь к Созвездию памяти.',
    '{"contentVersion":"chapter-1-v15","chapterId":"signal-chapter-1","nodeCount":28,"topology":"trail-memory-secret-route-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
