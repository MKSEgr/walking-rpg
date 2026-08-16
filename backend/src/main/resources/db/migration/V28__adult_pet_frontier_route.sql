-- Stage chapter-1-v12 without changing the active release. Adult-pet route
-- choices are served only after every pre-V28 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v12',
    'Первая глава: взрослый активный питомец открывает путь в Святилище созвездий.',
    '{"contentVersion":"chapter-1-v12","chapterId":"signal-chapter-1","nodeCount":26,"topology":"adult-pet-frontier-route-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
