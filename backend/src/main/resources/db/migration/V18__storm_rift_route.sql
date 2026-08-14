-- Stage chapter-1-v3 without changing the currently active release. The new
-- backend can serve both v2 and v3 during rollout; activation remains an
-- explicit operator action after every pre-V18 instance has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v3',
    'Первая глава: второй опциональный маршрут через грозовой скрипторий.',
    '{"contentVersion":"chapter-1-v3","chapterId":"signal-chapter-1","nodeCount":20,"topology":"storm-rift-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
