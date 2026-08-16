-- Stage chapter-1-v11 without changing the active release. Adult pet
-- evolution is served only after every pre-V27 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v11',
    'Первая глава: Искра, Мох и Руна открывают взрослую форму через второй порог связи.',
    '{"contentVersion":"chapter-1-v11","chapterId":"signal-chapter-1","nodeCount":25,"topology":"adult-starter-pet-evolution-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
