package com.walkingrpg.backend.platform.infrastructure;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import javax.sql.DataSource;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.json.JsonMapper;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivityBucket;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.expedition.application.EventResultAcknowledgementService;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
import com.walkingrpg.backend.platform.api.PlatformSnapshotResponse;
import com.walkingrpg.backend.platform.application.AccountDeletionReceipt;
import com.walkingrpg.backend.platform.application.PlatformAdminService;
import com.walkingrpg.backend.platform.application.PlatformCommandFingerprint;
import com.walkingrpg.backend.platform.application.PlatformContentCatalog;
import com.walkingrpg.backend.platform.application.PlatformIdempotencyConflictException;
import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.platform.application.PlatformValidationException;
import com.walkingrpg.backend.platform.domain.PlatformCommandScope;
import com.walkingrpg.backend.platform.domain.ProcessedPlatformCommand;
import com.walkingrpg.backend.platform.payment.PaymentProvider;
import com.walkingrpg.backend.platform.progress.PlatformProgressFacts;
import com.walkingrpg.backend.platform.progress.PlatformProgressFactsProvider;
import com.walkingrpg.backend.progression.application.ProgressionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.parallel.ResourceLock;
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
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class PlatformPersistenceIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-27T08:30:00Z");

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private PlatformService platformService;

    @Autowired
    private PlatformAdminService platformAdminService;

    @Autowired
    private ActivitySyncService activitySyncService;

    @Autowired
    private ExpeditionAdvanceService expeditionAdvanceService;

    @Autowired
    private EventResolutionService eventResolutionService;

    @Autowired
    private EventResultAcknowledgementService acknowledgementService;

    @Autowired
    private PlatformRepository platformRepository;

    @Autowired
    private PlatformContentCatalog contentCatalog;

    @Autowired
    private PlatformProgressFactsProvider progressFactsProvider;

    @Autowired
    private EconomyService economyService;

    @Autowired
    private PaymentProvider paymentProvider;

    @Autowired
    private ProgressionService progressionService;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private Clock clock;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute("TRUNCATE TABLE app_user CASCADE");
    }

    @Test
    void shouldProjectPersistedRemoteConfigIntoEveryPlatformCatalog() {
        PlatformSnapshotResponse snapshot = platformService.getSnapshot(
                "runtime-catalog-user"
        );
        Map<String, Object> bootstrap = platformService.getContentBootstrap();
        Map<String, Object> bootstrapContent = objectMap(bootstrap.get("content"));
        Map<String, Object> bootstrapConfig = objectMap(
                bootstrap.get("remoteConfig")
        );

        assertEquals(
                snapshot.remoteConfig().get("seasonId"),
                objectMap(snapshot.content().get("season")).get("seasonId")
        );
        assertEquals(
                snapshot.remoteConfig().get("weeklyRouteEnergy"),
                objectMap(snapshot.content().get("weeklyRoute"))
                        .get("requiredEnergy")
        );
        assertEquals(snapshot.content(), bootstrapContent);
        assertEquals(snapshot.remoteConfig(), bootstrapConfig);
    }

    @Test
    void shouldKeepInFlightCommandOnOneRemoteConfigPublication() throws Exception {
        String userId = "in-flight-config-user";
        Map<String, Object> previousRemoteConfig =
                platformRepository.activeRemoteConfig();
        platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "in-flight-config-seed",
                Map.of("stepId", "welcome")
        ));
        economyService.creditActivityEnergy(
                userId,
                100,
                "in-flight-config-energy",
                NOW
        );
        platformAdminService.updateRemoteConfig(
                "in-flight-config-test",
                "in-flight-command-config-a",
                commandRemoteConfig("command-season-a", 100, true)
        );

        ExecutorService executor = Executors.newSingleThreadExecutor();
        Future<PlatformCommandResponse> pending = null;
        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (PreparedStatement lock = blocker.prepareStatement("""
                        SELECT 1
                        FROM economy_wallet
                        WHERE user_id = ?
                          AND currency_code = 'ENERGY'
                        FOR UPDATE
                        """)) {
                    lock.setString(1, userId);
                    try (ResultSet rows = lock.executeQuery()) {
                        assertTrue(rows.next());
                    }
                }

                pending = executor.submit(() -> platformService.execute(
                        userId,
                        new PlatformCommandRequest(
                                "ADVANCE_WEEKLY_ROUTE",
                                "in-flight-command-config",
                                Map.of("energyToSpend", 100)
                        )
                ));
                awaitBlockedQuery("FROM economy_wallet");

                platformAdminService.updateRemoteConfig(
                        "in-flight-config-test",
                        "in-flight-command-config-b",
                        commandRemoteConfig("command-season-b", 200, false)
                );
                blocker.commit();
                PlatformCommandResponse response = pending.get(5, TimeUnit.SECONDS);

                assertEquals(
                        "command-season-a",
                        response.snapshot().remoteConfig().get("seasonId")
                );
                assertEquals(
                        100,
                        response.snapshot().remoteConfig().get("weeklyRouteEnergy")
                );
                assertEquals(
                        true,
                        response.snapshot().remoteConfig().get("weeklyRouteEnabled")
                );
                assertEquals(
                        100,
                        response.snapshot().userState().get("weeklyRouteRequiredEnergy")
                );
                assertEquals(
                        100,
                        response.snapshot().userState().get("weeklyRouteProgress")
                );
                assertEquals(120, response.snapshot().userState().get("seasonXp"));
                assertTrue(objectList(
                        response.snapshot().userState().get("achievements")
                ).contains("weekly-route-complete"));
                assertEquals(
                        "command-season-a",
                        objectMap(response.snapshot().content().get("season"))
                                .get("seasonId")
                );
                assertEquals(
                        100,
                        objectMap(response.snapshot().content().get("weeklyRoute"))
                                .get("requiredEnergy")
                );

                PlatformSnapshotResponse afterPublication = platformService.getSnapshot(userId);
                assertEquals(
                        "command-season-b",
                        afterPublication.remoteConfig().get("seasonId")
                );
                assertEquals(200, afterPublication.remoteConfig().get("weeklyRouteEnergy"));
                assertEquals(false, afterPublication.remoteConfig().get("weeklyRouteEnabled"));
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (pending != null && !pending.isDone()) {
                        pending.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        } finally {
            platformAdminService.updateRemoteConfig(
                    "in-flight-config-test",
                    "in-flight-command-config-restored",
                    previousRemoteConfig
            );
        }
    }

    @Test
    void shouldReplayPreStabilizationIndentedFingerprintAfterCompactRestart()
            throws Exception {
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, platformService.getSnapshot("platform-user").stateVersion());
        assertEquals(0, rowCount("app_user"));

        PlatformCommandRequest request = new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "welcome-once",
                Map.of("stepId", "welcome")
        );
        PlatformCommandResponse first = platformService.execute("platform-user", request);

        ObjectMapper historicalObjectMapper = JsonMapper.builder()
                .findAndAddModules()
                .enable(SerializationFeature.INDENT_OUTPUT)
                .build();
        String historicalFingerprint = previousApiMapperFingerprint(
                historicalObjectMapper,
                request.commandType(),
                request.payload()
        );
        jdbcTemplate.update("""
                UPDATE processed_roadmap_command
                SET request_fingerprint = ?
                WHERE user_id = ?
                  AND command_type = ?
                  AND idempotency_key = ?
                """,
                historicalFingerprint,
                "platform-user",
                request.commandType(),
                request.idempotencyKey()
        );
        PlatformService restarted = new PlatformService(
                platformRepository,
                contentCatalog,
                progressFactsProvider,
                economyService,
                paymentProvider,
                objectMapper,
                clock,
                progressionService
        );
        PlatformCommandResponse replayed = restarted.execute("platform-user", request);

        assertEquals(first, replayed);
        assertEquals(1, rowCount("app_user"));
        assertEquals(1, rowCount("roadmap_user_state"));
        assertEquals(1, rowCount("processed_roadmap_command"));
        assertEquals(1, rowCount("platform_event"));
        assertEquals(1, milestoneCount("platform-user", "JOURNEY_STARTED"));
        assertEquals(historicalFingerprint, scalarString("""
                SELECT request_fingerprint
                FROM processed_roadmap_command
                WHERE user_id = 'platform-user'
                """));
        assertEquals("welcome", jdbcTemplate.queryForObject("""
                SELECT state_json -> 'completedOnboardingSteps' ->> 0
                FROM roadmap_user_state
                WHERE user_id = 'platform-user'
                """, String.class));

        assertThrows(PlatformIdempotencyConflictException.class, () ->
                restarted.execute("platform-user", new PlatformCommandRequest(
                        "COMPLETE_ONBOARDING_STEP",
                        "welcome-once",
                        Map.of("stepId", "first-sync")
                ))
        );
    }

    @Test
    void shouldReplayCanonicalPlatformPayloadAfterRestartAndKeyReordering() {
        String userId = "canonical-fingerprint-user";
        String idempotencyKey = "canonical-compass-once";
        Map<String, Object> firstPayload = new LinkedHashMap<>();
        firstPayload.put("impression", "RECIPE_READY");
        firstPayload.put(
                "contentVersion",
                StarterExpeditionContent.CONTENT_VERSION
        );
        PlatformCommandResponse first = platformService.execute(
                userId,
                new PlatformCommandRequest(
                        "RECORD_COMPASS_IMPRESSION",
                        idempotencyKey,
                        firstPayload
                )
        );

        PlatformService restarted = new PlatformService(
                platformRepository,
                contentCatalog,
                progressFactsProvider,
                economyService,
                paymentProvider,
                objectMapper,
                clock,
                progressionService
        );
        Map<String, Object> reorderedPayload = new LinkedHashMap<>();
        reorderedPayload.put(
                "contentVersion",
                StarterExpeditionContent.CONTENT_VERSION
        );
        reorderedPayload.put("impression", "RECIPE_READY");
        PlatformCommandResponse replayed = restarted.execute(
                userId,
                new PlatformCommandRequest(
                        "RECORD_COMPASS_IMPRESSION",
                        idempotencyKey,
                        reorderedPayload
                )
        );

        assertEquals(first, replayed);
        assertEquals(1, rowCount("processed_roadmap_command"));
        assertEquals(2, rowCount("platform_event"));
        assertEquals(
                PlatformCommandFingerprint.sha256(
                        "RECORD_COMPASS_IMPRESSION",
                        reorderedPayload
                ),
                scalarString("""
                        SELECT request_fingerprint
                        FROM processed_roadmap_command
                        WHERE user_id = 'canonical-fingerprint-user'
                        """)
        );
    }

    @Test
    void shouldPersistOnePurchaseAcrossLegacyAndCanonicalCommandAliases() throws Exception {
        String userId = "payment-alias-user";
        String idempotencyKey = "payment-alias-once";
        Map<String, Object> payload = Map.of("cosmeticId", "spark-halo");
        Map<String, Object> previousRemoteConfig =
                platformRepository.activeRemoteConfig();
        platformAdminService.updateRemoteConfig(
                "payment-alias-test",
                "payment-alias-enabled",
                paymentRemoteConfig(true)
        );

        try {
            PlatformCommandResponse first = platformService.execute(
                    userId,
                    new PlatformCommandRequest(
                            "BUY_COSMETIC",
                            idempotencyKey,
                            payload
                    )
            );
            ProcessedPlatformCommand legacyProcessed = platformRepository.findProcessed(
                    new PlatformCommandScope(
                            userId,
                            "BUY_COSMETIC",
                            idempotencyKey
                    )
            ).orElseThrow();
            PlatformCommandResponse legacyInstanceReplay = objectMapper.readValue(
                    legacyProcessed.responseJson(),
                    PlatformCommandResponse.class
            );
            PlatformCommandResponse replayed = platformService.execute(
                    userId,
                    new PlatformCommandRequest(
                            "PURCHASE_COSMETIC",
                            idempotencyKey,
                            payload
                    )
            );

            assertEquals(first, legacyInstanceReplay);
            assertEquals(first, replayed);
            assertEquals("BUY_COSMETIC", first.commandType());
            assertEquals(
                    PlatformCommandFingerprint.sha256(
                            "BUY_COSMETIC",
                            payload
                    ),
                    legacyProcessed.requestFingerprint()
            );
            assertEquals(1, rowCount("payment_intent"));
            assertEquals(2, rowCount("processed_roadmap_command"));
            assertEquals(List.of("BUY_COSMETIC", "PURCHASE_COSMETIC"),
                    jdbcTemplate.queryForList("""
                    SELECT command_type
                    FROM processed_roadmap_command
                    WHERE user_id = 'payment-alias-user'
                    ORDER BY command_type
                    """, String.class));
            assertEquals(1L, jdbcTemplate.queryForObject("""
                    SELECT count(DISTINCT response_json)
                    FROM processed_roadmap_command
                    WHERE user_id = 'payment-alias-user'
                    """, Long.class));
            assertEquals("spark-halo", scalarString("""
                    SELECT product_id
                    FROM payment_intent
                    WHERE user_id = 'payment-alias-user'
                    """));

            assertThrows(PlatformIdempotencyConflictException.class, () ->
                    platformService.execute(
                            userId,
                            new PlatformCommandRequest(
                                    "PURCHASE_COSMETIC",
                                    idempotencyKey,
                                    Map.of("cosmeticId", "trail-banner")
                            )
                    )
            );
            assertEquals(1, rowCount("payment_intent"));
            assertEquals(2, rowCount("processed_roadmap_command"));
            assertFalse(Boolean.TRUE.equals(jdbcTemplate.queryForObject("""
                    SELECT (state_json -> 'ownedCosmetics') @> '["trail-banner"]'::jsonb
                    FROM roadmap_user_state
                    WHERE user_id = ?
                    """, Boolean.class, userId)));
        } finally {
            platformAdminService.updateRemoteConfig(
                    "payment-alias-test",
                    "payment-alias-restored",
                    previousRemoteConfig
            );
        }
    }

    @Test
    void shouldPersistIndependentCosmeticSlotsAcrossServiceRestart() {
        String userId = "cosmetic-slot-user";
        Map<String, Object> previousRemoteConfig =
                platformRepository.activeRemoteConfig();
        platformAdminService.updateRemoteConfig(
                "cosmetic-slot-test",
                "cosmetic-slot-payments-enabled",
                paymentRemoteConfig(true)
        );

        try {
            platformService.execute(userId, new PlatformCommandRequest(
                    "BUY_COSMETIC",
                    "buy-persisted-spark-halo",
                    Map.of("cosmeticId", "spark-halo")
            ));
            PlatformCommandRequest equipRequest = new PlatformCommandRequest(
                    "EQUIP_COSMETIC",
                    "equip-persisted-spark-halo",
                    Map.of("cosmeticId", "spark-halo")
            );
            PlatformCommandResponse equipped = platformService.execute(
                    userId,
                    equipRequest
            );

            PlatformService restarted = new PlatformService(
                    platformRepository,
                    contentCatalog,
                    progressFactsProvider,
                    economyService,
                    paymentProvider,
                    objectMapper,
                    clock,
                    progressionService
            );
            PlatformSnapshotResponse afterRestart = restarted.getSnapshot(userId);
            PlatformCommandResponse replayed = restarted.execute(userId, equipRequest);

            Map<String, String> expected = Map.of(
                    "PILOT", "pilot-scarf",
                    "PET", "spark-halo"
            );
            assertEquals(
                    expected,
                    stringMap(equipped.snapshot().userState().get("equippedCosmetics"))
            );
            assertEquals(
                    expected,
                    stringMap(afterRestart.userState().get("equippedCosmetics"))
            );
            assertEquals(equipped, replayed);
            assertEquals(2, rowCount("platform_cosmetic_slot_state"));
            assertEquals(2L, scalarLong("""
                    SELECT count(*)
                    FROM platform_cosmetic_slot_state
                    WHERE user_id = 'cosmetic-slot-user'
                      AND version = 1
                    """));
        } finally {
            platformAdminService.updateRemoteConfig(
                    "cosmetic-slot-test",
                    "cosmetic-slot-payments-restored",
                    previousRemoteConfig
            );
        }
    }

    @Test
    void shouldSerializeOwnerDeletionWithLastMemberLeave() throws Exception {
        String ownerId = "squad-delete-owner";
        String memberId = "squad-leave-member";
        PlatformCommandResponse created = platformService.execute(
                ownerId,
                new PlatformCommandRequest(
                        "CREATE_SQUAD",
                        "create-squad-for-deletion-race",
                        Map.of("name", "Concurrent squad")
                )
        );
        Object squad = created.snapshot().userState().get("squad");
        assertTrue(squad instanceof Map<?, ?>);
        String squadId = String.valueOf(((Map<?, ?>) squad).get("squadId"));
        platformService.execute(memberId, new PlatformCommandRequest(
                "JOIN_SQUAD",
                "join-squad-for-deletion-race",
                Map.of("squadId", squadId)
        ));

        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<AccountDeletionReceipt> deletion = null;
        Future<PlatformCommandResponse> leave = null;
        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (PreparedStatement lock = blocker.prepareStatement("""
                        SELECT 1
                        FROM roadmap_squad
                        WHERE squad_id = ?::uuid
                        FOR UPDATE
                        """)) {
                    lock.setString(1, squadId);
                    try (ResultSet rows = lock.executeQuery()) {
                        assertTrue(rows.next());
                    }
                }

                deletion = executor.submit(() ->
                        platformAdminService.requestAccountDeletion(
                                ownerId,
                                "delete-squad-owner",
                                "DELETE"
                        )
                );
                awaitBlockedQuery("UPDATE roadmap_squad");

                Future<PlatformCommandResponse> leaveTask = executor.submit(() ->
                        platformService.execute(memberId, new PlatformCommandRequest(
                                "LEAVE_SQUAD",
                                "leave-squad-during-owner-deletion",
                                Map.of()
                        ))
                );
                leave = leaveTask;
                awaitBlockedQuery("squad-membership-serialization");
                assertThrows(
                        TimeoutException.class,
                        () -> leaveTask.get(250, TimeUnit.MILLISECONDS)
                );

                blocker.commit();
                assertEquals("COMPLETED", deletion.get(5, TimeUnit.SECONDS).status());
                assertNull(leaveTask.get(5, TimeUnit.SECONDS)
                        .snapshot().userState().get("squad"));
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (deletion != null && !deletion.isDone()) {
                        deletion.cancel(true);
                    }
                    if (leave != null && !leave.isDone()) {
                        leave.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }

        assertEquals(0, jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM roadmap_squad
                WHERE squad_id = ?::uuid
                """, Integer.class, squadId));
        assertEquals(0, jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM roadmap_squad_member
                WHERE squad_id = ?::uuid
                """, Integer.class, squadId));
        assertEquals(0, jdbcTemplate.queryForObject(
                "SELECT count(*) FROM app_user WHERE user_id = ?",
                Integer.class,
                ownerId
        ));
        assertEquals(1, jdbcTemplate.queryForObject(
                "SELECT count(*) FROM app_user WHERE user_id = ?",
                Integer.class,
                memberId
        ));
    }

    @Test
    void shouldSerializeConcurrentRemoteConfigPublications() throws Exception {
        String previousVersion = scalarString("""
                SELECT config_version
                FROM remote_config_snapshot
                WHERE is_active
                """);
        List<Map<String, Object>> responses = runConcurrentPublications(
                """
                SELECT config_version
                FROM remote_config_snapshot
                WHERE is_active
                FOR UPDATE
                """,
                "UPDATE remote_config_snapshot",
                () -> platformAdminService.updateRemoteConfig(
                        "publication-operator-a",
                        "publication-lock-config-a",
                        publicationRemoteConfig("publication-season-a")
                ),
                () -> platformAdminService.updateRemoteConfig(
                        "publication-operator-b",
                        "publication-lock-config-b",
                        publicationRemoteConfig("publication-season-b")
                ),
                new PublicationRestoration(
                    "UPDATE remote_config_snapshot SET is_active = false WHERE is_active",
                    """
                    UPDATE remote_config_snapshot
                    SET is_active = true
                    WHERE config_version = ?
                    """,
                    """
                    DELETE FROM remote_config_snapshot
                    WHERE config_version LIKE ?
                    """,
                    previousVersion,
                    "publication-lock-config-%",
                    """
                    SELECT count(*)
                    FROM remote_config_snapshot
                    WHERE is_active
                    """,
                    """
                    SELECT config_version
                    FROM remote_config_snapshot
                    WHERE is_active
                    """,
                    "publication-lock-config-b"
                )
        );

        assertEquals("publication-lock-config-a", responses.get(0).get("version"));
        assertEquals("publication-lock-config-b", responses.get(1).get("version"));
        assertEquals(1L, scalarLong("""
                SELECT count(*)
                FROM remote_config_snapshot
                WHERE is_active
                """));
        assertEquals(previousVersion, scalarString("""
                SELECT config_version
                FROM remote_config_snapshot
                WHERE is_active
                """));
    }

    @Test
    void shouldSerializeConcurrentContentPublications() throws Exception {
        String previousVersion = scalarString("""
                SELECT content_version
                FROM content_release
                WHERE is_active
                """);
        List<Map<String, Object>> responses = runConcurrentPublications(
                """
                SELECT content_version
                FROM content_release
                WHERE is_active
                FOR UPDATE
                """,
                "UPDATE content_release",
                () -> platformAdminService.publishContent(
                        "publication-operator-a",
                        "publication-lock-content-a",
                        "Concurrent publication A",
                        Map.of("publication", "a")
                ),
                () -> platformAdminService.publishContent(
                        "publication-operator-b",
                        "publication-lock-content-b",
                        "Concurrent publication B",
                        Map.of("publication", "b")
                ),
                new PublicationRestoration(
                    "UPDATE content_release SET is_active = false WHERE is_active",
                    """
                    UPDATE content_release
                    SET is_active = true
                    WHERE content_version = ?
                    """,
                    """
                    DELETE FROM content_release
                    WHERE content_version LIKE ?
                    """,
                    previousVersion,
                    "publication-lock-content-%",
                    """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """,
                    """
                    SELECT content_version
                    FROM content_release
                    WHERE is_active
                    """,
                    "publication-lock-content-b"
                )
        );

        assertEquals(
                "publication-lock-content-a",
                responses.get(0).get("contentVersion")
        );
        assertEquals(
                "publication-lock-content-b",
                responses.get(1).get("contentVersion")
        );
        assertEquals(1L, scalarLong("""
                SELECT count(*)
                FROM content_release
                WHERE is_active
                """));
        assertEquals(previousVersion, scalarString("""
                SELECT content_version
                FROM content_release
                WHERE is_active
                """));
    }

    @Test
    void shouldReadPlatformSnapshotFromOneRepeatableSnapshot() throws Exception {
        String userId = "platform-snapshot-user";
        ensureUser(userId);
        PlatformSnapshotResponse duringConcurrentSync;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Future<PlatformSnapshotResponse> pending = null;
        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (Statement lock = blocker.createStatement()) {
                    lock.execute(
                            "LOCK TABLE processed_event_resolution "
                                    + "IN ACCESS EXCLUSIVE MODE"
                    );
                }

                pending = executor.submit(() -> platformService.getSnapshot(userId));
                awaitPlatformResolvedEventsReadBlock();

                jdbcTemplate.update("""
                        INSERT INTO activity_sync_state (
                            user_id, local_date, accepted_total, state_version,
                            time_zone, updated_at
                        ) VALUES (?, '2026-07-27', 1200, 1, 'Europe/Berlin', ?)
                        """, userId, Timestamp.from(NOW));
                jdbcTemplate.update("""
                        UPDATE app_user
                        SET has_successful_activity_sync = true
                        WHERE user_id = ?
                        """, userId);

                blocker.commit();
                duringConcurrentSync = pending.get(5, TimeUnit.SECONDS);
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (pending != null && !pending.isDone()) {
                        pending.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }

        assertEquals(
                0L,
                ((Number) duringConcurrentSync.userState()
                        .get("totalAcceptedSteps")).longValue()
        );
        assertEquals(
                false,
                duringConcurrentSync.userState().get("hasSuccessfulActivitySync")
        );
        assertEquals(1, rowCount("activity_sync_state"));
        assertTrue(Boolean.TRUE.equals(jdbcTemplate.queryForObject("""
                SELECT has_successful_activity_sync
                FROM app_user
                WHERE user_id = ?
                """, Boolean.class, userId)));

        PlatformSnapshotResponse afterSync = platformService.getSnapshot(userId);
        assertEquals(
                1200L,
                ((Number) afterSync.userState().get("totalAcceptedSteps")).longValue()
        );
        assertEquals(true, afterSync.userState().get("hasSuccessfulActivitySync"));
    }

    @Test
    void shouldKeepCompassTelemetryOutOfPersistentStateReconciliation() {
        String userId = "compass-telemetry-state-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "compass-telemetry-state-seed",
                Map.of("stepId", "welcome")
        ));
        String stateBefore = scalarString("""
                SELECT state_json::text
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """);
        long versionBefore = scalarLong("""
                SELECT version
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """);
        Timestamp updatedBefore = jdbcTemplate.queryForObject("""
                SELECT updated_at
                FROM roadmap_user_state
                WHERE user_id = ?
                """, Timestamp.class, userId);
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id, pet_id, level, bond, version,
                    created_at, updated_at
                ) VALUES (?, 'spark-v1', 1, 60, 1, ?, ?)
                """, userId, Timestamp.from(NOW), Timestamp.from(NOW));
        PlatformCommandRequest request = new PlatformCommandRequest(
                "RECORD_COMPASS_IMPRESSION",
                "compass-telemetry-state-neutral",
                Map.of(
                        "impression", "RECIPE_READY",
                        "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                )
        );

        PlatformCommandResponse first = platformService.execute(userId, request);
        PlatformCommandResponse replayed = platformService.execute(userId, request);

        assertEquals(first, replayed);
        assertEquals(versionBefore, first.stateVersion());
        assertEquals(stateBefore, scalarString("""
                SELECT state_json::text
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """));
        assertEquals(versionBefore, scalarLong("""
                SELECT version
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """));
        assertEquals(updatedBefore, jdbcTemplate.queryForObject("""
                SELECT updated_at
                FROM roadmap_user_state
                WHERE user_id = ?
                """, Timestamp.class, userId));
        assertEquals(2, rowCount("processed_roadmap_command"));
        assertEquals(3, rowCount("platform_event"));
    }

    @Test
    void shouldRecordPetSelectionAndCompletedJourneyOnlyOnce() {
        String userId = "journey-user";
        completeStep(userId, "welcome");
        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                "journey-device",
                LocalDate.of(2026, 7, 29),
                ZoneId.of("Europe/Berlin"),
                6_842,
                List.of(),
                null,
                "journey-first-sync",
                "signed-attestation"
        ));
        completeStep(userId, "health-permission");
        completeStep(userId, "first-sync");
        PlatformCommandRequest selection = new PlatformCommandRequest(
                "SELECT_PET",
                "journey-select-moss",
                Map.of("petId", "moss-v1")
        );
        platformService.execute(userId, selection);
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "journey-first-advance"
        ));
        completeStep(userId, "first-expedition");
        var event = eventResolutionService.resolve(new EventResolutionCommand(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "journey-first-event"
        ));
        PlatformCommandResponse completed = completeStep(userId, "first-event");

        platformService.execute(userId, selection);
        platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "journey-step-first-event",
                Map.of("stepId", "first-event")
        ));

        assertEquals(true, completed.snapshot().userState().get("onboardingComplete"));
        assertEquals(1, milestoneCount(userId, "JOURNEY_STARTED"));
        assertEquals(1, milestoneCount(userId, "FIRST_ACTIVITY_SYNC"));
        assertEquals(1, milestoneCount(userId, "FIRST_ENERGY"));
        assertEquals(1, milestoneCount(userId, "PET_SELECTED"));
        assertEquals(1, milestoneCount(userId, "FIRST_NODE_REACHED"));
        assertEquals(1, milestoneCount(userId, "FIRST_EVENT_RESOLVED"));
        assertEquals(1, milestoneCount(userId, "ONBOARDING_COMPLETED"));
        assertEquals(0, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals("moss-v1", jdbcTemplate.queryForObject("""
                SELECT attributes ->> 'petId'
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'PET_SELECTED'
                """, String.class, userId));

        var acknowledgement = acknowledgementService.acknowledge(
                userId,
                event.receiptId()
        );
        var replayedAcknowledgement = acknowledgementService.acknowledge(
                userId,
                event.receiptId()
        );

        assertEquals(acknowledgement, replayedAcknowledgement);
        assertEquals(1, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals(
                acknowledgement.acknowledgedAt(),
                jdbcTemplate.queryForObject("""
                        SELECT occurred_at
                        FROM first_journey_milestone
                        WHERE user_id = ?
                          AND milestone =
                              'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                        """, Timestamp.class, userId).toInstant()
        );
        assertEquals("AUTHORITATIVE", jdbcTemplate.queryForObject("""
                SELECT source
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """, String.class, userId));
        assertEquals("AUTHORITATIVE", jdbcTemplate.queryForObject("""
                SELECT source
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'ONBOARDING_COMPLETED'
                """, String.class, userId));
    }

    @Test
    void shouldDelayMeasuredCompletionUntilLastAuthoritativeFact() {
        String userId = "marker-only-journey-user";
        completeStep(userId, "welcome");
        completeStep(userId, "health-permission");
        completeStep(userId, "first-sync");
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "marker-only-select-moss",
                Map.of("petId", "moss-v1")
        ));
        completeStep(userId, "first-expedition");
        PlatformCommandResponse completed = completeStep(userId, "first-event");

        assertEquals(true, completed.snapshot().userState().get("onboardingComplete"));
        assertEquals(1, milestoneCount(userId, "JOURNEY_STARTED"));
        assertEquals(1, milestoneCount(userId, "PET_SELECTED"));
        assertEquals(0, milestoneCount(userId, "FIRST_ACTIVITY_SYNC"));
        assertEquals(0, milestoneCount(userId, "FIRST_ENERGY"));
        assertEquals(0, milestoneCount(userId, "FIRST_NODE_REACHED"));
        assertEquals(0, milestoneCount(userId, "FIRST_EVENT_RESOLVED"));
        assertEquals(0, milestoneCount(userId, "ONBOARDING_COMPLETED"));

        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                "delayed-journey-device",
                LocalDate.of(2026, 7, 29),
                ZoneId.of("Europe/Berlin"),
                6_842,
                List.of(),
                null,
                "delayed-journey-sync",
                "signed-attestation"
        ));
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "delayed-journey-advance"
        ));
        eventResolutionService.resolve(new EventResolutionCommand(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "delayed-journey-event"
        ));

        assertEquals(1, milestoneCount(userId, "FIRST_ACTIVITY_SYNC"));
        assertEquals(1, milestoneCount(userId, "FIRST_ENERGY"));
        assertEquals(1, milestoneCount(userId, "FIRST_NODE_REACHED"));
        assertEquals(1, milestoneCount(userId, "FIRST_EVENT_RESOLVED"));
        assertEquals(1, milestoneCount(userId, "ONBOARDING_COMPLETED"));
        assertEquals(0, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals(6, jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM processed_roadmap_command
                WHERE user_id = ?
                """, Integer.class, userId));
    }

    @Test
    void shouldSerializeConcurrentFinalJourneyFacts() throws Exception {
        String userId = "concurrent-journey-user";
        completeStep(userId, "welcome");
        completeStep(userId, "health-permission");
        completeStep(userId, "first-sync");
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "concurrent-select-moss",
                Map.of("petId", "moss-v1")
        ));
        completeStep(userId, "first-expedition");
        completeStep(userId, "first-event");
        Instant firstFactAt = Instant.now(clock)
                .plusSeconds(60)
                .truncatedTo(ChronoUnit.MICROS);
        jdbcTemplate.update("""
                INSERT INTO first_journey_milestone (
                    user_id, milestone, occurred_at, source,
                    attributes, recorded_at
                ) VALUES
                    (?, 'FIRST_ACTIVITY_SYNC', ?, 'AUTHORITATIVE', '{}'::jsonb, ?),
                    (?, 'FIRST_ENERGY', ?, 'AUTHORITATIVE', '{}'::jsonb, ?)
                """,
                userId,
                Timestamp.from(firstFactAt),
                Timestamp.from(firstFactAt),
                userId,
                Timestamp.from(firstFactAt.plusSeconds(1)),
                Timestamp.from(firstFactAt.plusSeconds(1))
        );

        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (Connection firstFact = dataSource.getConnection()) {
            firstFact.setAutoCommit(false);
            recordMilestone(
                    firstFact,
                    userId,
                    "FIRST_NODE_REACHED",
                    firstFactAt.plusSeconds(2)
            );
            recheckCompletion(firstFact, userId);

            Future<?> secondFact = executor.submit(() -> {
                try (Connection connection = dataSource.getConnection()) {
                    connection.setAutoCommit(false);
                    recordMilestone(
                            connection,
                            userId,
                            "FIRST_EVENT_RESOLVED",
                            firstFactAt.plusSeconds(3)
                    );
                    recheckCompletion(connection, userId);
                    connection.commit();
                    return null;
                }
            });

            awaitJourneyCompletionLockWait();
            firstFact.commit();
            secondFact.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(1, milestoneCount(userId, "ONBOARDING_COMPLETED"));
        assertEquals(
                firstFactAt.plusSeconds(3),
                jdbcTemplate.queryForObject("""
                        SELECT occurred_at
                        FROM first_journey_milestone
                        WHERE user_id = ?
                          AND milestone = 'ONBOARDING_COMPLETED'
                        """, Timestamp.class, userId).toInstant()
        );
    }

    @Test
    void shouldDebitWeeklyRouteOnlyOnceAndPersistDerivedAchievement() {
        ensureUser("weekly-user");
        economyService.creditActivityEnergy("weekly-user", 100, "weekly-seed", NOW);
        PlatformCommandRequest request = new PlatformCommandRequest(
                "ADVANCE_WEEKLY_ROUTE",
                "weekly-route-once",
                Map.of("energyToSpend", 100)
        );

        PlatformCommandResponse first = platformService.execute("weekly-user", request);
        PlatformCommandResponse replayed = platformService.execute("weekly-user", request);

        assertEquals(first, replayed);
        assertEquals(0L, scalarLong("""
                SELECT balance
                FROM economy_wallet
                WHERE user_id = 'weekly-user' AND currency_code = 'ENERGY'
                """));
        assertEquals(2, rowCount("economy_ledger"));
        assertEquals(1, rowCount("processed_roadmap_command"));
        assertEquals("100", scalarString("""
                SELECT state_json ->> 'weeklyRouteProgress'
                FROM roadmap_user_state
                WHERE user_id = 'weekly-user'
                """));
        assertEquals("120", scalarString("""
                SELECT state_json ->> 'seasonXp'
                FROM roadmap_user_state
                WHERE user_id = 'weekly-user'
                """));
        assertTrue(Boolean.TRUE.equals(jdbcTemplate.queryForObject("""
                SELECT (state_json -> 'achievements') @> '["weekly-route-complete"]'::jsonb
                FROM roadmap_user_state
                WHERE user_id = 'weekly-user'
                """, Boolean.class)));
    }

    @Test
    void shouldRollbackFractionalPlatformCommandBeforePersistingState() {
        PlatformValidationException exception = assertThrows(
                PlatformValidationException.class,
                () -> platformService.execute(
                        "fractional-command-user",
                        new PlatformCommandRequest(
                                "ADVANCE_WEEKLY_ROUTE",
                                "fractional-command-key",
                                Map.of("energyToSpend", 1.25)
                        )
                )
        );

        assertEquals("energyToSpend", exception.field());
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("roadmap_user_state"));
        assertEquals(0, rowCount("processed_roadmap_command"));
        assertEquals(0, rowCount("platform_event"));
        assertEquals(0, rowCount("economy_wallet"));
        assertEquals(0, rowCount("economy_ledger"));
    }

    @Test
    void shouldRejectMalformedSquadIdsBeforePersistentState() {
        PlatformValidationException malformed = assertThrows(
                PlatformValidationException.class,
                () -> platformService.execute(
                        "malformed-squad-user",
                        new PlatformCommandRequest(
                                "JOIN_SQUAD",
                                "join-malformed-squad",
                                Map.of("squadId", "not-a-uuid")
                        )
                )
        );
        PlatformValidationException shortened = assertThrows(
                PlatformValidationException.class,
                () -> platformService.execute(
                        "short-squad-user",
                        new PlatformCommandRequest(
                                "JOIN_SQUAD",
                                "join-short-squad",
                                Map.of("squadId", "1-1-1-1-1")
                        )
                )
        );

        assertEquals("squadId", malformed.field());
        assertEquals("squadId", shortened.field());
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("roadmap_user_state"));
        assertEquals(0, rowCount("processed_roadmap_command"));
        assertEquals(0, rowCount("platform_event"));
        assertEquals(0, rowCount("roadmap_squad"));
        assertEquals(0, rowCount("roadmap_squad_member"));
    }

    @Test
    void shouldPersistBlockingRiskSignalWithoutRejectingActivityInShadowMode() {
        ActivitySyncCommand command = new ActivitySyncCommand(
                "risk-user",
                "risk-device",
                LocalDate.of(2026, 7, 27),
                ZoneId.of("Europe/Berlin"),
                120_000,
                List.of(new ActivityBucket(NOW.minusSeconds(60), NOW, 120_000)),
                null,
                "risk-sync-1",
                "signed-attestation"
        );

        ActivitySyncOutcome outcome = activitySyncService.synchronize(command);

        assertEquals(120_000, outcome.activity().acceptedDelta());
        assertEquals(1_200, outcome.energyBalanceAfter());
        assertEquals(1, rowCount("activity_risk_assessment"));
        assertEquals("BLOCK", scalarString("""
                SELECT decision
                FROM activity_risk_assessment
                WHERE user_id = 'risk-user'
                """));
        assertEquals(100, scalarLong("""
                SELECT risk_score
                FROM activity_risk_assessment
                WHERE user_id = 'risk-user'
                """));
        assertEquals(1, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("activity_sync_state"));
    }

    @Test
    void shouldExposeSuccessfulZeroStepSyncAsDurablePlatformFact() {
        ActivitySyncOutcome outcome = activitySyncService.synchronize(
                new ActivitySyncCommand(
                        "zero-step-user",
                        "zero-step-device",
                        LocalDate.of(2026, 7, 27),
                        ZoneId.of("Europe/Berlin"),
                        0,
                        List.of(),
                        null,
                        "zero-step-sync-1",
                        "signed-attestation"
                )
        );

        assertEquals(1, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("app_device"));
        assertEquals(0, rowCount("activity_sync_state"));

        jdbcTemplate.update("DELETE FROM processed_activity_sync");
        jdbcTemplate.update("DELETE FROM activity_risk_assessment");

        PlatformProgressFacts facts = progressFactsProvider.factsFor("zero-step-user");
        Map<String, Object> userState = platformService
                .getSnapshot("zero-step-user")
                .userState();

        assertEquals(0, outcome.activity().acceptedTotal());
        assertEquals(0, facts.totalAcceptedSteps());
        assertTrue(facts.hasSuccessfulActivitySync());
        assertEquals(true, userState.get("hasSuccessfulActivitySync"));
        assertEquals(0, rowCount("processed_activity_sync"));
        assertEquals(0, rowCount("activity_risk_assessment"));
        assertEquals(1, rowCount("app_device"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(1, milestoneCount(
                "zero-step-user",
                "FIRST_ACTIVITY_SYNC"
        ));
        assertEquals(0, milestoneCount("zero-step-user", "FIRST_ENERGY"));
    }

    @Test
    void shouldNotTreatPushOnlyDeviceAsSuccessfulActivitySync() {
        platformAdminService.registerPush(
                "push-only-user",
                "push-only-device",
                "ANDROID",
                "FCM",
                "push-only-token"
        );

        PlatformProgressFacts facts = progressFactsProvider.factsFor(
                "push-only-user"
        );
        Boolean marker = jdbcTemplate.queryForObject("""
                SELECT has_successful_activity_sync
                FROM app_user
                WHERE user_id = 'push-only-user'
                """, Boolean.class);

        assertEquals(1, rowCount("app_device"));
        assertEquals(1, rowCount("push_registration"));
        assertFalse(Boolean.TRUE.equals(marker));
        assertFalse(facts.hasSuccessfulActivitySync());
    }

    @Test
    @ResourceLock("java.util.Locale.default")
    void shouldCanonicalizeProtocolTokensIndependentlyOfJvmLocale() {
        Locale previousLocale = Locale.getDefault();
        Locale previousDisplayLocale = Locale.getDefault(Locale.Category.DISPLAY);
        Locale previousFormatLocale = Locale.getDefault(Locale.Category.FORMAT);
        PlatformCommandResponse response;
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"));
            response = platformService.execute(
                    "locale-token-user",
                    new PlatformCommandRequest(
                            "record_compass_impression",
                            "locale-compass-impression",
                            Map.of(
                                    "impression", "recipe_ready",
                                    "contentVersion", "chapter-1-v2"
                            )
                    )
            );
            platformAdminService.registerPush(
                    "locale-token-user",
                    "locale-device",
                    "ios",
                    "firebase",
                    "locale-push-token"
            );
            platformAdminService.recordCrash(
                    "locale-token-user",
                    "ios",
                    "1.0.0",
                    "locale-test",
                    "locale-test-message",
                    null,
                    Map.of(),
                    NOW
            );
            platformAdminService.upsertTester(
                    "locale-admin",
                    "locale-cohort",
                    "locale-token-user",
                    "active",
                    null
            );
        } finally {
            Locale.setDefault(previousLocale);
            Locale.setDefault(Locale.Category.DISPLAY, previousDisplayLocale);
            Locale.setDefault(Locale.Category.FORMAT, previousFormatLocale);
        }

        assertEquals(previousLocale, Locale.getDefault());
        assertEquals(previousDisplayLocale, Locale.getDefault(Locale.Category.DISPLAY));
        assertEquals(previousFormatLocale, Locale.getDefault(Locale.Category.FORMAT));
        assertEquals("RECORD_COMPASS_IMPRESSION", response.commandType());
        assertEquals("compass_recipe_impression", scalarString("""
                SELECT event_name
                FROM platform_event
                WHERE user_id = 'locale-token-user'
                  AND event_name = 'compass_recipe_impression'
                """));
        assertEquals("READY", scalarString("""
                SELECT attributes ->> 'status'
                FROM platform_event
                WHERE user_id = 'locale-token-user'
                  AND event_name = 'compass_recipe_impression'
                """));
        assertEquals("IOS", scalarString("""
                SELECT platform
                FROM push_registration
                WHERE user_id = 'locale-token-user'
                  AND device_id = 'locale-device'
                """));
        assertEquals("FIREBASE", scalarString("""
                SELECT provider
                FROM push_registration
                WHERE user_id = 'locale-token-user'
                  AND device_id = 'locale-device'
                """));
        assertEquals("IOS", scalarString("""
                SELECT platform
                FROM platform_crash_report
                WHERE user_id = 'locale-token-user'
                """));
        assertEquals("ACTIVE", scalarString("""
                SELECT status
                FROM tester_cohort_member
                WHERE cohort_code = 'locale-cohort'
                  AND user_id = 'locale-token-user'
                """));
    }

    @Test
    void shouldUseServerReceiptTimeForTelemetryRetention() throws Exception {
        Instant cohortStartedAt = Instant.parse("2026-06-01T10:00:00Z");
        ensureUser("forged-client-time", cohortStartedAt);
        ensureUser("server-day-one", cohortStartedAt);
        ensureUser("server-day-seven", cohortStartedAt);
        ensureUser("server-day-thirty", cohortStartedAt);

        recordPlatformEvent(
                "forged-client-time",
                cohortStartedAt.plus(30, ChronoUnit.DAYS),
                cohortStartedAt.plus(1, ChronoUnit.HOURS)
        );
        recordPlatformEvent(
                "server-day-one",
                cohortStartedAt.minus(30, ChronoUnit.DAYS),
                cohortStartedAt.plus(1, ChronoUnit.DAYS)
        );
        recordPlatformEvent(
                "server-day-seven",
                cohortStartedAt.minus(30, ChronoUnit.DAYS),
                cohortStartedAt.plus(7, ChronoUnit.DAYS)
        );
        recordPlatformEvent(
                "server-day-thirty",
                cohortStartedAt.plus(30, ChronoUnit.DAYS),
                cohortStartedAt.plus(30, ChronoUnit.DAYS)
        );
        assertReceiptTimeRetentionRangeUsesDedicatedIndex();

        Map<String, Object> summary = platformAdminService.retentionSummary();

        assertEquals(4L, summary.get("cohortSize"));
        assertEquals(
                Map.of("day", 1, "retainedUsers", 1L, "rate", 0.25),
                summary.get("d1")
        );
        assertEquals(
                Map.of("day", 7, "retainedUsers", 1L, "rate", 0.25),
                summary.get("d7")
        );
        assertEquals(
                Map.of("day", 30, "retainedUsers", 1L, "rate", 0.25),
                summary.get("d30")
        );
    }

    @Test
    void shouldReadRetentionFromOneRepeatableSnapshot() throws Exception {
        Map<String, Object> duringInsert;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (Connection blocker = dataSource.getConnection()) {
            blocker.setAutoCommit(false);
            try (PreparedStatement lock = blocker.prepareStatement(
                    "LOCK TABLE platform_event IN ACCESS EXCLUSIVE MODE"
            )) {
                lock.execute();
            }

            Future<Map<String, Object>> pending = executor.submit(
                    platformAdminService::retentionSummary
            );
            awaitRetentionEventReadBlock();

            try (PreparedStatement insertUser = blocker.prepareStatement("""
                    INSERT INTO app_user (
                        user_id, created_at, last_seen_at
                    ) VALUES ('concurrent-retention-user', ?, ?)
                    """);
                 PreparedStatement insertEvent = blocker.prepareStatement("""
                    INSERT INTO platform_event (
                        user_id, event_name, occurred_at,
                        attributes, received_at
                    ) VALUES (
                        'concurrent-retention-user', 'retention-test', ?,
                        '{}'::jsonb, ?
                    )
                    """)) {
                Timestamp createdAt = Timestamp.from(
                        Instant.parse("2026-06-01T10:00:00Z")
                );
                Timestamp returnedAt = Timestamp.from(
                        Instant.parse("2026-06-02T10:00:00Z")
                );
                insertUser.setTimestamp(1, createdAt);
                insertUser.setTimestamp(2, createdAt);
                insertUser.executeUpdate();
                insertEvent.setTimestamp(1, returnedAt);
                insertEvent.setTimestamp(2, returnedAt);
                insertEvent.executeUpdate();
            }
            blocker.commit();
            duringInsert = pending.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(0L, duringInsert.get("cohortSize"));
        assertEquals(
                Map.of("day", 1, "retainedUsers", 0L, "rate", 0.0),
                duringInsert.get("d1")
        );
        assertEquals(1, rowCount("app_user"));
        assertEquals(1, rowCount("platform_event"));

        Map<String, Object> afterInsert = platformAdminService.retentionSummary();
        assertEquals(1L, afterInsert.get("cohortSize"));
        assertEquals(
                Map.of("day", 1, "retainedUsers", 1L, "rate", 1.0),
                afterInsert.get("d1")
        );
    }

    private void ensureUser(String userId) {
        ensureUser(userId, NOW);
    }

    private void ensureUser(String userId, Instant createdAt) {
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, created_at, last_seen_at) VALUES (?, ?, ?)",
                userId,
                Timestamp.from(createdAt),
                Timestamp.from(createdAt)
        );
    }

    private void recordPlatformEvent(
            String userId,
            Instant occurredAt,
            Instant receivedAt
    ) {
        jdbcTemplate.update("""
                INSERT INTO platform_event (
                    user_id, event_name, occurred_at, attributes, received_at
                ) VALUES (?, 'retention-test', ?, '{}'::jsonb, ?)
                """,
                userId,
                Timestamp.from(occurredAt),
                Timestamp.from(receivedAt)
        );
    }

    private void assertReceiptTimeRetentionRangeUsesDedicatedIndex()
            throws Exception {
        try (Connection connection = dataSource.getConnection();
             Statement statement = connection.createStatement()) {
            statement.execute("SET enable_seqscan = off");
            try (ResultSet result = statement.executeQuery("""
                    EXPLAIN (COSTS OFF)
                    SELECT 1
                    FROM platform_event
                    WHERE user_id = 'server-day-one'
                      AND received_at >=
                          TIMESTAMPTZ '2026-06-02T00:00:00Z'
                      AND received_at <
                          TIMESTAMPTZ '2026-06-03T00:00:00Z'
                    """)) {
                StringBuilder plan = new StringBuilder();
                while (result.next()) {
                    plan.append(result.getString(1)).append('\n');
                }
                assertTrue(
                        plan.toString().contains(
                                "ix_platform_event_user_received_at"
                        ),
                        () -> "Receipt-time range did not use its index:\n"
                                + plan
                );
            }
        }
    }

    private void awaitRetentionEventReadBlock() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE '%e.received_at%'
                    """, Integer.class);
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Retention query did not reach the blocked event read"
        );
    }

    private void awaitPlatformResolvedEventsReadBlock() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE '%FROM processed_event_resolution%'
                    """, Integer.class);
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Platform snapshot did not reach the blocked event fact read"
        );
    }

    private void awaitBlockedQuery(String queryFragment) throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE ?
                    """, Integer.class, "%" + queryFragment + "%");
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Expected query did not reach the blocked state: " + queryFragment
        );
    }

    private List<Map<String, Object>> runConcurrentPublications(
            String activeRowLockSql,
            String firstBlockedQuery,
            Callable<Map<String, Object>> firstPublication,
            Callable<Map<String, Object>> secondPublication,
            PublicationRestoration restoration
    ) throws Exception {
        try (Connection blocker = dataSource.getConnection()) {
            ExecutorService executor = Executors.newFixedThreadPool(2);
            Future<Map<String, Object>> first = null;
            Future<Map<String, Object>> second = null;
            try {
                blocker.setAutoCommit(false);
                try (Statement lock = blocker.createStatement();
                     ResultSet rows = lock.executeQuery(activeRowLockSql)) {
                    assertTrue(rows.next());
                }

                Future<Map<String, Object>> firstTask = executor.submit(
                        firstPublication
                );
                first = firstTask;
                awaitBlockedQuery(firstBlockedQuery);

                Future<Map<String, Object>> secondTask = executor.submit(
                        secondPublication
                );
                second = secondTask;
                awaitBlockedQuery("platform-publication-serialization");
                assertThrows(
                        TimeoutException.class,
                        () -> firstTask.get(250, TimeUnit.MILLISECONDS)
                );
                assertThrows(
                        TimeoutException.class,
                        () -> secondTask.get(250, TimeUnit.MILLISECONDS)
                );

                blocker.commit();
                List<Map<String, Object>> responses = List.of(
                        firstTask.get(5, TimeUnit.SECONDS),
                        secondTask.get(5, TimeUnit.SECONDS)
                );
                assertEquals(1L, scalarLong(restoration.activeCountSql()));
                assertEquals(
                        restoration.expectedActiveVersion(),
                        scalarString(restoration.activeVersionSql())
                );
                return responses;
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (first != null && !first.isDone()) {
                        first.cancel(true);
                    }
                    if (second != null && !second.isDone()) {
                        second.cancel(true);
                    }
                    executor.shutdownNow();
                    if (!executor.awaitTermination(20, TimeUnit.SECONDS)) {
                        throw new IllegalStateException(
                                "Publication executor did not terminate after cancellation"
                        );
                    }
                    restorePublicationState(restoration);
                }
            }
        }
    }

    private void restorePublicationState(PublicationRestoration restoration)
            throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            try {
                connection.setAutoCommit(false);
                try (Statement deactivate = connection.createStatement()) {
                    deactivate.executeUpdate(restoration.deactivateSql());
                }
                try (PreparedStatement activate = connection.prepareStatement(
                        restoration.activateSql()
                )) {
                    activate.setString(1, restoration.previousVersion());
                    if (activate.executeUpdate() != 1) {
                        throw new IllegalStateException(
                                "Previous active publication was not restored"
                        );
                    }
                }
                try (PreparedStatement delete = connection.prepareStatement(
                        restoration.deleteSql()
                )) {
                    delete.setString(1, restoration.testVersionPattern());
                    delete.executeUpdate();
                }
                connection.commit();
            } finally {
                connection.rollback();
            }
        }
    }

    private record PublicationRestoration(
            String deactivateSql,
            String activateSql,
            String deleteSql,
            String previousVersion,
            String testVersionPattern,
            String activeCountSql,
            String activeVersionSql,
            String expectedActiveVersion
    ) {
    }

    private Map<String, Object> publicationRemoteConfig(String seasonId) {
        return Map.of(
                "backgroundHealthSyncEnabled", false,
                "activityRetentionDays", 30,
                "seasonId", seasonId,
                "weeklyRouteEnergy", 120,
                "sandboxPaymentsEnabled", false,
                "weeklyRouteEnabled", true
        );
    }

    private Map<String, Object> commandRemoteConfig(
            String seasonId,
            int weeklyRouteEnergy,
            boolean weeklyRouteEnabled
    ) {
        return Map.of(
                "backgroundHealthSyncEnabled", false,
                "activityRetentionDays", 30,
                "seasonId", seasonId,
                "weeklyRouteEnergy", weeklyRouteEnergy,
                "sandboxPaymentsEnabled", false,
                "weeklyRouteEnabled", weeklyRouteEnabled
        );
    }

    private Map<String, Object> paymentRemoteConfig(boolean enabled) {
        return Map.of(
                "backgroundHealthSyncEnabled", false,
                "activityRetentionDays", 30,
                "seasonId", "season-1",
                "weeklyRouteEnergy", 120,
                "sandboxPaymentsEnabled", enabled,
                "weeklyRouteEnabled", true
        );
    }

    private PlatformCommandResponse completeStep(String userId, String stepId) {
        return platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "journey-step-" + stepId,
                Map.of("stepId", stepId)
        ));
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }

    private int milestoneCount(String userId, String milestone) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = ?
                """, Integer.class, userId, milestone);
        return count == null ? 0 : count;
    }

    private void recordMilestone(
            Connection connection,
            String userId,
            String milestone,
            Instant occurredAt
    ) throws Exception {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT record_first_journey_milestone(
                    ?::varchar,
                    ?::varchar,
                    ?::timestamptz,
                    '{}'::jsonb
                )
                """)) {
            statement.setString(1, userId);
            statement.setString(2, milestone);
            statement.setString(3, occurredAt.toString());
            statement.execute();
        }
    }

    private void recheckCompletion(Connection connection, String userId)
            throws Exception {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT record_first_journey_completion_if_ready(?::varchar)
                """)) {
            statement.setString(1, userId);
            statement.execute();
        }
    }

    private void awaitJourneyCompletionLockWait() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND lower(wait_event) = 'advisory'
                      AND query LIKE
                          '%record_first_journey_completion_if_ready%'
                    """, Integer.class);
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Concurrent milestone did not wait for completion serialization"
        );
    }

    private long scalarLong(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value == null ? 0 : value;
    }

    private String scalarString(String sql) {
        return jdbcTemplate.queryForObject(sql, String.class);
    }

    private String previousApiMapperFingerprint(
            ObjectMapper mapper,
            String commandType,
            Map<String, Object> payload
    ) throws Exception {
        Map<String, Object> envelope = new TreeMap<>();
        envelope.put("commandType", commandType);
        envelope.put("payload", new TreeMap<>(payload));
        byte[] bytes = mapper.writeValueAsString(envelope)
                .getBytes(StandardCharsets.UTF_8);
        return HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(bytes)
        );
    }

    @SuppressWarnings("unchecked")
    private static Map<String, String> stringMap(Object value) {
        return (Map<String, String>) value;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> objectMap(Object value) {
        return (Map<String, Object>) value;
    }

    @SuppressWarnings("unchecked")
    private static List<Object> objectList(Object value) {
        return (List<Object>) value;
    }
}
