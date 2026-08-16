package com.walkingrpg.backend.itemupgrade.infrastructure;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.time.LocalDate;
import java.util.UUID;

import com.walkingrpg.backend.crafting.application.InsufficientCraftingMaterialsException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeService;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeStateConflictException;
import com.walkingrpg.backend.itemupgrade.application.StarterItemUpgradeContent;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeCommand;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class ItemUpgradeIntegrationTest {

    private static final UUID ITEM_INSTANCE_ID = UUID.fromString(
            "70000000-0000-0000-0000-000000000001"
    );

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private ItemUpgradeService service;

    @Autowired
    private HomeService homeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute(
                "TRUNCATE TABLE account_deletion_receipt, app_user CASCADE"
        );
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = ?
                """, StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION);
    }

    @Test
    void shouldUpgradeSameItemExactlyOnceAndProjectCompletedHomeState() {
        seedOwnedPrism("upgrade-user");
        seedMaterials("upgrade-user", 4, 2, 1);
        ItemUpgradeCommand command = command("upgrade-user", "upgrade-1");
        HomeSnapshotResponse readyHome = homeService.getSnapshot(new HomeQuery(
                "upgrade-user",
                LocalDate.of(2026, 8, 15)
        ));
        assertEquals("READY", readyHome.itemUpgrades().getFirst().status());

        ItemUpgradeResult first = service.upgrade(command);
        ItemUpgradeResult replay = service.upgrade(command);

        assertEquals(first, replay);
        assertEquals(ITEM_INSTANCE_ID, first.upgradedItem().itemInstanceId());
        assertEquals(1, first.upgradedItem().previousLevel());
        assertEquals(2, first.upgradedItem().upgradeLevel());
        assertEquals("RARE", first.upgradedItem().rarity().name());
        assertEquals(1, rowCount("unique_inventory_item"));
        assertEquals(1, rowCount("processed_item_upgrade_command"));
        assertEquals(3, rowCount("processed_item_upgrade_ingredient"));
        assertEquals(3, rowCount("inventory_ledger"));
        assertEquals(-4L, jdbcTemplate.queryForObject("""
                SELECT sum(quantity_delta)
                FROM inventory_ledger
                WHERE user_id = 'upgrade-user'
                  AND source_type = 'ITEM_UPGRADE_COMMAND'
                """, Long.class));
        assertEquals(2, quantity("upgrade-user", "echo-thread"));
        assertEquals(1, quantity("upgrade-user", "prism-dust"));
        assertEquals(0, quantity("upgrade-user", "ion-bloom"));

        HomeSnapshotResponse home = homeService.getSnapshot(new HomeQuery(
                "upgrade-user",
                LocalDate.of(2026, 8, 15)
        ));
        assertEquals("COMPLETED", home.itemUpgrades().getFirst().status());
        assertEquals("RARE", home.inventory().stream()
                .filter(item -> item.itemId().equals("prism-sextant"))
                .findFirst()
                .orElseThrow()
                .rarity());

        ItemUpgradeStateConflictException error = assertThrows(
                ItemUpgradeStateConflictException.class,
                () -> service.upgrade(command("upgrade-user", "upgrade-2"))
        );
        assertEquals("ALREADY_COMPLETED", error.reason());
        assertEquals(3, rowCount("inventory_ledger"));
    }

    @Test
    void shouldAttuneRareSextantToEpicExactlyOnceOnChapterV8() {
        activateContent(
                StarterExpeditionContent.SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        );
        seedOwnedPrism("attunement-user", 2, "RARE");
        seedMaterials("attunement-user", 4, 0, 3);
        insertStack("attunement-user", "dawn-fragment", 2);

        HomeSnapshotResponse readyHome = homeService.getSnapshot(new HomeQuery(
                "attunement-user",
                LocalDate.of(2026, 8, 16)
        ));
        assertEquals(2, readyHome.itemUpgrades().size());
        assertEquals("COMPLETED", readyHome.itemUpgrades().get(0).status());
        assertEquals("READY", readyHome.itemUpgrades().get(1).status());

        ItemUpgradeCommand command = command(
                "attunement-user",
                StarterItemUpgradeContent
                        .PRISM_SEXTANT_SECOND_DAWN_ATTUNEMENT_ID,
                "attune-1"
        );
        ItemUpgradeResult first = service.upgrade(command);
        ItemUpgradeResult replay = service.upgrade(command);

        assertEquals(first, replay);
        assertEquals(ITEM_INSTANCE_ID, first.upgradedItem().itemInstanceId());
        assertEquals(2, first.upgradedItem().previousLevel());
        assertEquals(3, first.upgradedItem().upgradeLevel());
        assertEquals("EPIC", first.upgradedItem().rarity().name());
        assertEquals(1, rowCount("unique_inventory_item"));
        assertEquals(1, rowCount("processed_item_upgrade_command"));
        assertEquals(3, rowCount("processed_item_upgrade_ingredient"));
        assertEquals(3, rowCount("inventory_ledger"));
        assertEquals(2, quantity("attunement-user", "echo-thread"));
        assertEquals(1, quantity("attunement-user", "ion-bloom"));
        assertEquals(0, quantity("attunement-user", "dawn-fragment"));

        HomeSnapshotResponse completedHome = homeService.getSnapshot(
                new HomeQuery(
                        "attunement-user",
                        LocalDate.of(2026, 8, 16)
                )
        );
        assertEquals("COMPLETED", completedHome.itemUpgrades().get(0).status());
        assertEquals("COMPLETED", completedHome.itemUpgrades().get(1).status());
        assertEquals("EPIC", completedHome.inventory().stream()
                .filter(item -> item.itemId().equals("prism-sextant"))
                .findFirst()
                .orElseThrow()
                .rarity());

        ItemUpgradeStateConflictException error = assertThrows(
                ItemUpgradeStateConflictException.class,
                () -> service.upgrade(command(
                        "attunement-user",
                        StarterItemUpgradeContent
                                .PRISM_SEXTANT_SECOND_DAWN_ATTUNEMENT_ID,
                        "attune-2"
                ))
        );
        assertEquals("ALREADY_COMPLETED", error.reason());
        assertEquals(3, rowCount("inventory_ledger"));
    }

    @Test
    void shouldReportAllShortagesWithoutMutatingItemOrInventory() {
        seedOwnedPrism("missing-user");
        seedMaterials("missing-user", 1, 0, 0);

        InsufficientCraftingMaterialsException error = assertThrows(
                InsufficientCraftingMaterialsException.class,
                () -> service.upgrade(command("missing-user", "missing"))
        );

        assertEquals(3, error.shortages().size());
        assertEquals(1, quantity("missing-user", "echo-thread"));
        assertEquals(1L, jdbcTemplate.queryForObject("""
                SELECT version
                FROM unique_inventory_item
                WHERE user_id = 'missing-user'
                """, Long.class));
        assertEquals(0, rowCount("inventory_ledger"));
        assertEquals(0, rowCount("processed_item_upgrade_command"));
        HomeSnapshotResponse home = homeService.getSnapshot(new HomeQuery(
                "missing-user",
                LocalDate.of(2026, 8, 15)
        ));
        assertEquals(
                "MISSING_MATERIALS",
                home.itemUpgrades().getFirst().status()
        );
    }

    @Test
    void shouldKeepLockedHomeProjectionUntilTargetIsOwned() {
        seedUser("locked-user");
        seedMaterials("locked-user", 4, 2, 1);

        HomeSnapshotResponse home = homeService.getSnapshot(new HomeQuery(
                "locked-user",
                LocalDate.of(2026, 8, 15)
        ));

        assertEquals(1, home.itemUpgrades().size());
        assertEquals("LOCKED", home.itemUpgrades().getFirst().status());
        ItemUpgradeStateConflictException error = assertThrows(
                ItemUpgradeStateConflictException.class,
                () -> service.upgrade(command("locked-user", "locked"))
        );
        assertEquals("TARGET_NOT_OWNED", error.reason());
        assertEquals(0, rowCount("inventory_ledger"));
    }

    private void seedOwnedPrism(String userId) {
        seedOwnedPrism(userId, 1, "UNCOMMON");
    }

    private void seedOwnedPrism(String userId, long level, String rarity) {
        seedUser(userId);
        jdbcTemplate.update("""
                INSERT INTO unique_inventory_item (
                    item_instance_id, user_id, item_id, recipe_id,
                    recipe_version, version, rarity, crafted_at, upgraded_at
                ) VALUES (?, ?, 'prism-sextant', 'prism-sextant-v1',
                          '1', ?, ?, now(), CASE WHEN ? > 1 THEN now() END)
                """, ITEM_INSTANCE_ID, userId, level, rarity, level);
    }

    private void seedUser(String userId) {
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, now(), now())
                """, userId);
    }

    private void seedMaterials(
            String userId,
            long echoThread,
            long prismDust,
            long ionBloom
    ) {
        insertStack(userId, "echo-thread", echoThread);
        insertStack(userId, "prism-dust", prismDust);
        insertStack(userId, "ion-bloom", ionBloom);
    }

    private void insertStack(String userId, String itemId, long quantity) {
        jdbcTemplate.update("""
                INSERT INTO inventory_stack (
                    user_id, item_id, quantity, version, created_at, updated_at
                ) VALUES (?, ?, ?, 1, now(), now())
                """, userId, itemId, quantity);
    }

    private ItemUpgradeCommand command(String userId, String idempotencyKey) {
        return command(
                userId,
                StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID,
                idempotencyKey
        );
    }

    private ItemUpgradeCommand command(
            String userId,
            String upgradeId,
            String idempotencyKey
    ) {
        return new ItemUpgradeCommand(
                userId,
                upgradeId,
                idempotencyKey
        );
    }

    private void activateContent(String contentVersion) {
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = ?
                """, contentVersion);
    }

    private long quantity(String userId, String itemId) {
        Long value = jdbcTemplate.queryForObject("""
                SELECT quantity
                FROM inventory_stack
                WHERE user_id = ? AND item_id = ?
                """, Long.class, userId, itemId);
        return value == null ? 0 : value;
    }

    private int rowCount(String table) {
        Integer value = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return value == null ? 0 : value;
    }
}
