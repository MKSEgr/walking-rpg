ALTER TABLE unique_inventory_item
    DROP CONSTRAINT ck_unique_inventory_item_rarity,
    ADD CONSTRAINT ck_unique_inventory_item_rarity
        CHECK (rarity IN ('COMMON', 'UNCOMMON', 'RARE', 'EPIC'));

ALTER TABLE processed_item_upgrade_command
    DROP CONSTRAINT processed_item_upgrade_command_result_rarity_check,
    ADD CONSTRAINT ck_processed_item_upgrade_result_rarity
        CHECK (result_rarity IN ('RARE', 'EPIC'));

CREATE OR REPLACE FUNCTION enforce_unique_item_refinement_v21()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.item_id = 'prism-sextant' THEN
        IF NEW.version = 1 THEN
            NEW.rarity := 'UNCOMMON';
            NEW.upgraded_at := NULL;
        ELSIF NEW.version = 2 THEN
            IF NEW.rarity <> 'RARE' OR NEW.upgraded_at IS NULL THEN
                RAISE EXCEPTION
                    'prism-sextant level 2 requires RARE rarity and upgraded_at';
            END IF;
        ELSIF NEW.version = 3 THEN
            IF NEW.rarity <> 'EPIC' OR NEW.upgraded_at IS NULL THEN
                RAISE EXCEPTION
                    'prism-sextant level 3 requires EPIC rarity and upgraded_at';
            END IF;
        ELSE
            RAISE EXCEPTION 'unsupported prism-sextant level: %', NEW.version;
        END IF;
    ELSIF NEW.version = 1 AND NEW.upgraded_at IS NULL THEN
        NEW.rarity := 'COMMON';
    END IF;
    RETURN NEW;
END;
$$;

-- Stage the rollout gate without changing the active chapter. V8 keeps the
-- V7 expedition topology and exposes only the additive level-3 attunement.
INSERT INTO content_release (
    content_version,
    release_notes,
    content_json,
    is_active,
    created_by,
    created_at
)
VALUES (
    'chapter-1-v8',
    'Первая глава: секстант принимает настройку второго рассвета.',
    '{"contentVersion":"chapter-1-v8","chapterId":"signal-chapter-1","nodeCount":24,"topology":"second-dawn-attunement-v1"}'::jsonb,
    false,
    'flyway',
    now()
);
