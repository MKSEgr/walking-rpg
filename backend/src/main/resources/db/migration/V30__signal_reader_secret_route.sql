-- Stage chapter-1-v14 without changing the active release. The secret route
-- is activated only after every pre-V30 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v14',
    'Первая глава: Чтение сигналов открывает Обсерваторию скрытого сигнала.',
    '{"contentVersion":"chapter-1-v14","chapterId":"signal-chapter-1","nodeCount":27,"topology":"signal-reader-secret-route-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
