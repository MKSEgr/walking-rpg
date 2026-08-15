-- Stage chapter-1-v5 without changing the currently active release. The new
-- backend can serve v1-v5 during rollout; activation remains an explicit
-- operator action after every pre-V20 instance has drained.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v5',
    'Первая глава: призматический секстант и скрытый путь через спектральную обсерваторию.',
    '{"contentVersion":"chapter-1-v5","chapterId":"signal-chapter-1","nodeCount":23,"topology":"prism-sextant-route-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
