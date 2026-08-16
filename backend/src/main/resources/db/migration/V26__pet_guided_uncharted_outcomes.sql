-- Stage chapter-1-v10 without changing the active release. The additive
-- active-pet outcomes are served only after every pre-V26 backend drains.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v10',
    'Первая глава: активный питомец открывает собственный исход на неизведанном рубеже.',
    '{"contentVersion":"chapter-1-v10","chapterId":"signal-chapter-1","nodeCount":25,"topology":"pet-guided-uncharted-outcomes-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
