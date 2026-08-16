-- Stage chapter-1-v16 without changing the active release. The Energy
-- Discipline route is activated only after every pre-V32 backend has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v16',
    'Первая глава: «Дисциплина энергии» стабилизирует путь к Меридиану рассвета.',
    '{"contentVersion":"chapter-1-v16","chapterId":"signal-chapter-1","nodeCount":29,"topology":"energy-discipline-dawn-meridian-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
