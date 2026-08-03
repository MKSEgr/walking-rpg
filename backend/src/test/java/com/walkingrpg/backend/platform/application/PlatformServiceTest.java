package com.walkingrpg.backend.platform.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import tools.jackson.databind.json.JsonMapper;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
import com.walkingrpg.backend.platform.api.PlatformSnapshotResponse;
import com.walkingrpg.backend.platform.domain.PlatformCommandScope;
import com.walkingrpg.backend.platform.domain.PlatformUserState;
import com.walkingrpg.backend.platform.domain.ProcessedPlatformCommand;
import com.walkingrpg.backend.platform.infrastructure.InMemoryPlatformRepository;
import com.walkingrpg.backend.platform.payment.DisabledPaymentProvider;
import com.walkingrpg.backend.platform.payment.PaymentProvider;
import com.walkingrpg.backend.platform.payment.SandboxPaymentProvider;
import com.walkingrpg.backend.platform.progress.PlatformProgressFacts;
import com.walkingrpg.backend.platform.progress.PlatformProgressFactsProvider;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.infrastructure.InMemoryProgressionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PlatformServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-27T08:30:00Z");

    private InMemoryPlatformRepository platformRepository;
    private InMemoryEconomyRepository economyRepository;
    private EconomyService economyService;
    private MutableFactsProvider factsProvider;
    private PlatformService service;

    @BeforeEach
    void setUp() {
        platformRepository = new InMemoryPlatformRepository();
        economyRepository = new InMemoryEconomyRepository();
        economyService = new EconomyService(economyRepository);
        factsProvider = new MutableFactsProvider();
        service = service(new SandboxPaymentProvider());
    }

    private PlatformService service(PaymentProvider paymentProvider) {
        return new PlatformService(
                platformRepository,
                new PlatformContentCatalog(),
                factsProvider,
                economyService,
                paymentProvider,
                JsonMapper.builder().findAndAddModules().build(),
                Clock.fixed(NOW, ZoneOffset.UTC),
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                )
        );
    }

    @Test
    void shouldReturnStableReadOnlyInitialSnapshot() {
        PlatformSnapshotResponse first = service.getSnapshot("user-1");
        PlatformSnapshotResponse second = service.getSnapshot("user-1");

        assertEquals(first, second);
        assertEquals("chapter-1-v2", first.contentVersion());
        assertEquals(0, first.stateVersion());
        assertEquals("spark-v1", first.userState().get("activePetId"));
        assertEquals(false, first.userState().get("hasSuccessfulActivitySync"));
        assertEquals(3, list(first.userState(), "pets").size());
        assertEquals(19, first.content().get("chapterNodes"));
        assertTrue(platformRepository.findState("user-1").isEmpty());
    }

    @Test
    void shouldKeepSnapshotAndBootstrapOnClusterActiveContentVersion() {
        platformRepository.setContentVersion(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION
        );

        PlatformSnapshotResponse snapshot = service.getSnapshot("legacy-user");
        Map<String, Object> bootstrap = service.getContentBootstrap();

        assertEquals("chapter-1-v1", snapshot.contentVersion());
        assertEquals("chapter-1-v1", snapshot.content().get("contentVersion"));
        assertEquals(18, snapshot.content().get("chapterNodes"));
        assertEquals("chapter-1-v1", bootstrap.get("contentVersion"));
        assertEquals(
                "chapter-1-v1",
                map(bootstrap.get("content")).get("contentVersion")
        );
        assertEquals(18, map(bootstrap.get("content")).get("chapterNodes"));
    }

    @Test
    void shouldPersistAndReplayOnboardingCommandExactly() {
        PlatformCommandRequest request = command(
                "COMPLETE_ONBOARDING_STEP",
                "onboarding-welcome-1",
                Map.of("stepId", "welcome")
        );

        PlatformCommandResponse first = service.execute("user-1", request);
        PlatformCommandResponse replayed = service.execute("user-1", request);

        assertEquals(first, replayed);
        assertEquals(1, first.stateVersion());
        assertTrue(collection(first.snapshot().userState(), "completedOnboardingSteps")
                .contains("welcome"));
        assertEquals(1, platformRepository.processedCommandCount());
        assertEquals(1, platformRepository.eventCount());
        assertTrue(platformRepository.findState("user-1").isPresent());
    }

    @Test
    void shouldMakePetSelectionAnAtomicOnboardingMilestone() {
        PlatformCommandResponse selected = service.execute("user-1", command(
                "SELECT_PET",
                "select-moss-onboarding",
                Map.of("petId", "moss-v1")
        ));

        assertEquals("moss-v1", selected.snapshot().userState().get("activePetId"));
        assertTrue(collection(
                selected.snapshot().userState(),
                "completedOnboardingSteps"
        ).contains("pet-selection"));
        assertEquals(1, selected.stateVersion());

        PlatformCommandResponse replayed = service.execute("user-1", command(
                "SELECT_PET",
                "select-moss-onboarding",
                Map.of("petId", "moss-v1")
        ));
        assertEquals(selected, replayed);
    }

    @Test
    void shouldRejectReusedIdempotencyKeyWithDifferentPayload() {
        service.execute("user-1", command(
                "COMPLETE_ONBOARDING_STEP",
                "shared-key",
                Map.of("stepId", "welcome")
        ));

        assertThrows(PlatformIdempotencyConflictException.class, () ->
                service.execute("user-1", command(
                        "COMPLETE_ONBOARDING_STEP",
                        "shared-key",
                        Map.of("stepId", "first-sync")
                ))
        );
    }

    @Test
    void shouldClaimReadyQuestAndRewardActivePet() {
        factsProvider.set("user-1", new PlatformProgressFacts(4_000, 0, 10, null));

        PlatformCommandResponse response = service.execute("user-1", command(
                "CLAIM_QUEST",
                "claim-walk-3000",
                Map.of("questId", "walk-3000")
        ));

        assertEquals(60, number(response.snapshot().userState(), "seasonXp"));
        assertEquals(
                true,
                response.snapshot().userState().get("hasSuccessfulActivitySync")
        );
        assertTrue(collection(response.snapshot().userState(), "claimedQuests")
                .contains("walk-3000"));
        Map<String, Object> spark = list(response.snapshot().userState(), "pets").stream()
                .map(PlatformServiceTest::map)
                .filter(pet -> "spark-v1".equals(pet.get("petId")))
                .findFirst()
                .orElseThrow();
        assertEquals(14, number(spark, "bond"));
    }

    @Test
    void shouldDebitWeeklyEnergyOnlyOnceAcrossExactReplay() {
        economyService.creditActivityEnergy("user-1", 120, "seed-energy", NOW);
        PlatformCommandRequest request = command(
                "ADVANCE_WEEKLY_ROUTE",
                "weekly-route-1",
                Map.of("energyToSpend", 120)
        );

        PlatformCommandResponse first = service.execute("user-1", request);
        PlatformCommandResponse replayed = service.execute("user-1", request);

        assertEquals(first, replayed);
        assertEquals(120, number(first.snapshot().userState(), "weeklyRouteProgress"));
        assertEquals(120, number(first.snapshot().userState(), "seasonXp"));
        assertTrue(collection(first.snapshot().userState(), "achievements")
                .contains("weekly-route-complete"));
        assertEquals(0, economyRepository.currentBalance(
                "user-1", EconomyCurrency.ENERGY, NOW
        ).balance());
        assertEquals(1, platformRepository.processedCommandCount());
    }

    @Test
    void shouldEvolvePetWhenBondThresholdIsReached() {
        factsProvider.set("user-1", new PlatformProgressFacts(0, 0, 60, null));

        PlatformCommandResponse response = service.execute("user-1", command(
                "EVOLVE_PET",
                "evolve-spark-1",
                Map.of("petId", "spark-v1")
        ));

        Map<String, Object> spark = list(response.snapshot().userState(), "pets").stream()
                .map(PlatformServiceTest::map)
                .filter(pet -> "spark-v1".equals(pet.get("petId")))
                .findFirst()
                .orElseThrow();
        assertEquals(2, number(spark, "level"));
        assertEquals(1, number(spark, "evolutionStage"));
        assertTrue(collection(response.snapshot().userState(), "achievements")
                .contains("pet-friend"));
    }

    @Test
    void shouldEnforceSkillSeasonRequirementAndUnlockAvailableSkill() {
        PlatformStateConflictException conflict = assertThrows(
                PlatformStateConflictException.class,
                () -> service.execute("user-1", command(
                        "UNLOCK_SKILL",
                        "unlock-trail-memory-too-early",
                        Map.of("skillId", "trail-memory")
                ))
        );
        assertEquals(100, conflict.details().get("requiredSeasonXp"));

        PlatformCommandResponse response = service.execute("user-1", command(
                "UNLOCK_SKILL",
                "unlock-steady-step",
                Map.of("skillId", "steady-step")
        ));
        assertTrue(collection(response.snapshot().userState(), "unlockedSkills")
                .contains("steady-step"));
    }

    @Test
    void shouldPurchaseAndEquipSandboxCosmetic() {
        platformRepository.setRemoteConfig(remoteConfig(true, false));

        PlatformCommandResponse purchased = service.execute("user-1", command(
                "BUY_COSMETIC",
                "buy-spark-halo",
                Map.of("cosmeticId", "spark-halo")
        ));
        PlatformCommandResponse equipped = service.execute("user-1", command(
                "EQUIP_COSMETIC",
                "equip-spark-halo",
                Map.of("cosmeticId", "spark-halo")
        ));

        assertTrue(collection(purchased.snapshot().userState(), "ownedCosmetics")
                .contains("spark-halo"));
        assertTrue(collection(purchased.snapshot().userState(), "achievements")
                .contains("first-cosmetic"));
        assertEquals("spark-halo", equipped.snapshot().userState().get("activeCosmeticId"));
        assertEquals(1, platformRepository.paymentCount());
    }

    @Test
    void shouldSharePurchaseIdempotencyAcrossCommandAliases() {
        platformRepository.setRemoteConfig(remoteConfig(true, false));
        PlatformCommandRequest legacyRequest = command(
                "BUY_COSMETIC",
                "shared-purchase-alias",
                Map.of("cosmeticId", "spark-halo")
        );

        PlatformCommandResponse first = service.execute("alias-user", legacyRequest);
        PlatformCommandResponse replayed = service.execute("alias-user", command(
                "PURCHASE_COSMETIC",
                "shared-purchase-alias",
                Map.of("cosmeticId", "spark-halo")
        ));

        assertEquals(first, replayed);
        assertEquals("BUY_COSMETIC", first.commandType());
        assertEquals(1, platformRepository.paymentCount());
        assertEquals(1, platformRepository.processedCommandCount());
        assertEquals(1, platformRepository.eventCount());

        assertThrows(PlatformIdempotencyConflictException.class, () ->
                service.execute("alias-user", command(
                        "PURCHASE_COSMETIC",
                        "shared-purchase-alias",
                        Map.of("cosmeticId", "trail-banner")
                ))
        );
        PlatformSnapshotResponse snapshot = service.getSnapshot("alias-user");
        assertTrue(collection(snapshot.userState(), "ownedCosmetics")
                .contains("spark-halo"));
        assertFalse(collection(snapshot.userState(), "ownedCosmetics")
                .contains("trail-banner"));
        assertEquals(1, platformRepository.paymentCount());
        assertEquals(1, platformRepository.processedCommandCount());
        assertEquals(1, platformRepository.eventCount());
    }

    @Test
    void shouldReplayLegacyBuyCosmeticRecordThroughCanonicalAlias() throws Exception {
        platformRepository.setRemoteConfig(remoteConfig(true, false));
        String userId = "legacy-alias-user";
        String idempotencyKey = "legacy-buy-record";
        Map<String, Object> payload = Map.of("cosmeticId", "spark-halo");
        PlatformSnapshotResponse snapshot = service.getSnapshot(userId);
        PlatformCommandResponse legacyResponse = new PlatformCommandResponse(
                "BUY_COSMETIC",
                idempotencyKey,
                "Sandbox-покупка выполнена",
                snapshot.stateVersion(),
                snapshot,
                NOW
        );
        JsonMapper mapper = JsonMapper.builder().findAndAddModules().build();
        platformRepository.saveProcessed(
                new PlatformCommandScope(userId, "BUY_COSMETIC", idempotencyKey),
                new ProcessedPlatformCommand(
                        PlatformCommandFingerprint.sha256(
                                mapper,
                                "BUY_COSMETIC",
                                payload
                        ),
                        mapper.writeValueAsString(legacyResponse)
                ),
                NOW
        );

        PlatformCommandResponse replayed = service.execute(userId, command(
                "PURCHASE_COSMETIC",
                idempotencyKey,
                payload
        ));

        assertEquals(legacyResponse, replayed);
        assertEquals(0, platformRepository.paymentCount());
        assertEquals(1, platformRepository.processedCommandCount());
        assertEquals(0, platformRepository.eventCount());
        assertTrue(platformRepository.findState(userId).isEmpty());
    }

    @Test
    void shouldRejectUnavailablePurchaseBeforeStateOrAnyOtherWrite() {
        platformRepository.setRemoteConfig(remoteConfig(true, true));
        PlatformService disabledService = service(new DisabledPaymentProvider());

        assertThrows(PlatformStateConflictException.class, () ->
                disabledService.execute("provider-user", command(
                        "BUY_COSMETIC",
                        "disabled-purchase",
                        Map.of("cosmeticId", "spark-halo")
                ))
        );

        assertTrue(platformRepository.findState("provider-user").isEmpty());
        assertEquals(0, platformRepository.paymentCount());
        assertEquals(0, platformRepository.processedCommandCount());
        assertEquals(0, platformRepository.eventCount());
        assertEquals(0, factsProvider.calls());

        Map<String, Object> bootstrap = map(
                disabledService.getContentBootstrap().get("remoteConfig")
        );
        assertEquals(false, bootstrap.get("sandboxPaymentsEnabled"));
        assertEquals(false, bootstrap.get("backgroundHealthSyncEnabled"));
    }

    @Test
    void shouldReplayCompletedPurchaseAfterProviderIsDisabled() {
        platformRepository.setRemoteConfig(remoteConfig(true, false));
        PlatformCommandRequest request = command(
                "PURCHASE_COSMETIC",
                "provider-transition-purchase",
                Map.of("cosmeticId", "spark-halo")
        );
        PlatformCommandResponse completed = service.execute("provider-user", request);

        platformRepository.setRemoteConfig(remoteConfig(false, false));
        PlatformService disabledService = service(new DisabledPaymentProvider());
        PlatformCommandResponse replayed = disabledService.execute("provider-user", request);

        assertEquals(completed.commandType(), replayed.commandType());
        assertEquals(completed.idempotencyKey(), replayed.idempotencyKey());
        assertEquals(completed.message(), replayed.message());
        assertEquals(completed.stateVersion(), replayed.stateVersion());
        assertEquals(completed.serverTime(), replayed.serverTime());
        assertEquals(
                completed.snapshot().userState(),
                replayed.snapshot().userState()
        );
        assertEquals(completed.snapshot().content(), replayed.snapshot().content());
        assertFalse((Boolean) replayed.snapshot().remoteConfig()
                .get("sandboxPaymentsEnabled"));
        assertFalse((Boolean) replayed.snapshot().remoteConfig()
                .get("backgroundHealthSyncEnabled"));
        assertEquals(1, platformRepository.paymentCount());
        assertEquals(1, platformRepository.processedCommandCount());
        assertEquals(1, platformRepository.eventCount());
        assertThrows(PlatformIdempotencyConflictException.class, () ->
                disabledService.execute("provider-user", command(
                        "PURCHASE_COSMETIC",
                        "provider-transition-purchase",
                        Map.of("cosmeticId", "trail-banner")
                ))
        );
    }

    @Test
    void shouldProjectOnlyEffectiveProviderCapabilities() {
        platformRepository.setRemoteConfig(remoteConfig(true, true));
        PlatformService disabledService = service(new DisabledPaymentProvider());

        PlatformSnapshotResponse snapshot = disabledService.getSnapshot("provider-user");
        assertFalse((Boolean) snapshot.remoteConfig().get("sandboxPaymentsEnabled"));
        assertFalse((Boolean) snapshot.remoteConfig().get("backgroundHealthSyncEnabled"));
        assertTrue(platformRepository.findState("provider-user").isEmpty());
    }

    @Test
    void shouldCreateJoinAndLeaveSquad() {
        PlatformCommandResponse created = service.execute("owner", command(
                "CREATE_SQUAD",
                "create-squad-1",
                Map.of("name", "Шагатели")
        ));
        String squadId = String.valueOf(map(
                created.snapshot().userState().get("squad")
        ).get("squadId"));
        factsProvider.set("owner", new PlatformProgressFacts(0, 0, 10, squadId));

        PlatformCommandResponse joined = service.execute("member", command(
                "JOIN_SQUAD",
                "join-squad-1",
                Map.of("squadId", squadId)
        ));
        factsProvider.set("member", new PlatformProgressFacts(0, 0, 10, squadId));

        assertEquals(squadId, map(
                joined.snapshot().userState().get("squad")
        ).get("squadId"));
        assertTrue(platformRepository.findSquadForUser("member").orElseThrow()
                .memberUserIds().containsAll(List.of("owner", "member")));

        PlatformCommandResponse left = service.execute("member", command(
                "LEAVE_SQUAD",
                "leave-squad-1",
                Map.of()
        ));
        assertNull(left.snapshot().userState().get("squad"));
        assertTrue(platformRepository.findSquadForUser("member").isEmpty());
    }

    @Test
    void shouldRecordAssignedExperimentExposureAndRejectWrongVariant() {
        PlatformSnapshotResponse snapshot = service.getSnapshot("user-1");
        Map<String, String> assignments = stringMap(
                snapshot.userState().get("experimentAssignments")
        );
        String experimentId = assignments.keySet().iterator().next();
        String assignedVariant = assignments.get(experimentId);

        PlatformCommandResponse response = service.execute("user-1", command(
                "RECORD_EXPERIMENT_EXPOSURE",
                "exposure-1",
                Map.of("experimentId", experimentId, "variant", assignedVariant)
        ));

        assertEquals("Exposure зарегистрирован", response.message());
        assertEquals(2, platformRepository.eventCount());
        assertThrows(PlatformStateConflictException.class, () ->
                service.execute("user-1", command(
                        "RECORD_EXPERIMENT_EXPOSURE",
                        "exposure-wrong",
                        Map.of("experimentId", experimentId, "variant", "WRONG")
                ))
        );
    }

    @Test
    void shouldRecordCanonicalCompassImpressionsAndReplayExactly() {
        PlatformCommandRequest recipeRequest = command(
                "RECORD_COMPASS_IMPRESSION",
                "compass-recipe-ready-v2",
                Map.of(
                        "impression", "recipe_ready",
                        "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                )
        );

        PlatformCommandResponse first = service.execute("user-1", recipeRequest);
        PlatformCommandResponse replayed = service.execute("user-1", recipeRequest);

        assertEquals(first, replayed);
        assertEquals("Показ компаса зарегистрирован", first.message());
        assertEquals(0, first.stateVersion());
        assertEquals(1, platformRepository.processedCommandCount());
        assertEquals(2, platformRepository.eventCount());
        assertTrue(platformRepository.findState("user-1").isEmpty());
        assertEquals(
                Map.of(
                        "contractVersion", "compass-beta-funnel-v1",
                        "contentVersion", "chapter-1-v2",
                        "recipeId", "resonance-compass-v1",
                        "status", "READY"
                ),
                map(event("compass_recipe_impression").get("attributes"))
        );

        PlatformCommandRequest routeRequest = command(
                "RECORD_COMPASS_IMPRESSION",
                "compass-route-available-v2",
                Map.of(
                        "impression", "ROUTE_AVAILABLE",
                        "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                )
        );
        PlatformCommandResponse routeResponse = service.execute(
                "user-1",
                routeRequest
        );

        assertEquals(
                Map.of(
                        "contractVersion", "compass-beta-funnel-v1",
                        "contentVersion", "chapter-1-v2",
                        "eventId", "mirror-delta-v1",
                        "choiceId", "follow-resonance",
                        "availability", "AVAILABLE"
                ),
                map(event("compass_route_impression").get("attributes"))
        );
        assertEquals(4, platformRepository.eventCount());

        platformRepository.setContentVersion(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION
        );
        assertEquals(routeResponse, service.execute("user-1", routeRequest));
        assertEquals(4, platformRepository.eventCount());

        assertThrows(PlatformIdempotencyConflictException.class, () ->
                service.execute("user-1", command(
                        "RECORD_COMPASS_IMPRESSION",
                        "compass-route-available-v2",
                        Map.of(
                                "impression", "ROUTE_LOCKED",
                                "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                        )
                ))
        );
    }

    @Test
    void shouldKeepCompassImpressionOutOfStateReconciliation() {
        service.execute("user-1", command(
                "COMPLETE_ONBOARDING_STEP",
                "telemetry-state-seed",
                Map.of("stepId", "welcome")
        ));
        PlatformUserState storedBefore = platformRepository
                .findState("user-1")
                .orElseThrow();
        factsProvider.set("user-1", new PlatformProgressFacts(0, 1, 60, null));
        PlatformCommandRequest request = command(
                "RECORD_COMPASS_IMPRESSION",
                "telemetry-state-neutral",
                Map.of(
                        "impression", "RECIPE_READY",
                        "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                )
        );

        PlatformCommandResponse first = service.execute("user-1", request);
        PlatformCommandResponse replayed = service.execute("user-1", request);
        int responseBond = list(first.snapshot().userState(), "pets").stream()
                .map(PlatformServiceTest::map)
                .filter(pet -> "spark-v1".equals(pet.get("petId")))
                .mapToInt(pet -> number(pet, "bond"))
                .findFirst()
                .orElseThrow();

        assertEquals(first, replayed);
        assertEquals(storedBefore.version(), first.stateVersion());
        assertEquals(storedBefore.pets().get("spark-v1").bond(), responseBond);
        assertEquals(
                storedBefore,
                platformRepository.findState("user-1").orElseThrow()
        );
        assertFalse(storedBefore.achievements().contains("pet-friend"));
        assertEquals(2, platformRepository.processedCommandCount());
        assertEquals(3, platformRepository.eventCount());
    }

    @Test
    void shouldRejectInvalidOrInactiveCompassImpressions() {
        PlatformValidationException unknownImpression = assertThrows(
                PlatformValidationException.class,
                () -> service.execute("user-1", command(
                        "RECORD_COMPASS_IMPRESSION",
                        "compass-unknown",
                        Map.of(
                                "impression", "UNKNOWN",
                                "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                        )
                ))
        );
        assertEquals("impression", unknownImpression.field());

        PlatformValidationException unknownVersion = assertThrows(
                PlatformValidationException.class,
                () -> service.execute("user-1", command(
                        "RECORD_COMPASS_IMPRESSION",
                        "compass-unknown-version",
                        Map.of(
                                "impression", "RECIPE_READY",
                                "contentVersion", "chapter-unknown"
                        )
                ))
        );
        assertEquals("contentVersion", unknownVersion.field());

        platformRepository.setContentVersion(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION
        );
        PlatformValidationException inactiveRoute = assertThrows(
                PlatformValidationException.class,
                () -> service.execute("user-1", command(
                        "RECORD_COMPASS_IMPRESSION",
                        "compass-route-before-activation",
                        Map.of(
                                "impression", "ROUTE_LOCKED",
                                "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                        )
                ))
        );
        assertEquals("contentVersion", inactiveRoute.field());

        PlatformCommandResponse legacyRecipe = service.execute("user-1", command(
                "RECORD_COMPASS_IMPRESSION",
                "compass-recipe-legacy",
                Map.of(
                        "impression", "RECIPE_MISSING_MATERIALS",
                        "contentVersion", StarterExpeditionContent.LEGACY_CONTENT_VERSION
                )
        ));
        assertEquals("Показ компаса зарегистрирован", legacyRecipe.message());
    }

    @Test
    void shouldClaimSeasonRewardAfterCompletingWeeklyRoute() {
        economyService.creditActivityEnergy("user-1", 120, "season-seed", NOW);
        service.execute("user-1", command(
                "ADVANCE_WEEKLY_ROUTE",
                "weekly-for-season",
                Map.of("energyToSpend", 120)
        ));

        PlatformCommandResponse reward = service.execute("user-1", command(
                "CLAIM_SEASON_REWARD",
                "season-reward-1",
                Map.of("level", 1)
        ));

        assertTrue(collection(reward.snapshot().userState(), "achievements")
                .contains("season-reward-1"));
    }

    private PlatformCommandRequest command(
            String commandType,
            String idempotencyKey,
            Map<String, Object> payload
    ) {
        return new PlatformCommandRequest(commandType, idempotencyKey, payload);
    }

    private Map<String, Object> remoteConfig(
            boolean sandboxPaymentsEnabled,
            boolean backgroundHealthSyncEnabled
    ) {
        return Map.of(
                "backgroundHealthSyncEnabled", backgroundHealthSyncEnabled,
                "activityRetentionDays", 30,
                "seasonId", "season-1",
                "weeklyRouteEnergy", 120,
                "sandboxPaymentsEnabled", sandboxPaymentsEnabled,
                "weeklyRouteEnabled", true
        );
    }

    @SuppressWarnings("unchecked")
    private static Collection<Object> collection(Map<String, Object> map, String key) {
        return (Collection<Object>) map.get(key);
    }

    @SuppressWarnings("unchecked")
    private static List<Object> list(Map<String, Object> map, String key) {
        return (List<Object>) map.get(key);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object value) {
        return (Map<String, Object>) value;
    }

    private Map<String, Object> event(String eventName) {
        return platformRepository.events().stream()
                .filter(event -> eventName.equals(event.get("eventName")))
                .findFirst()
                .orElseThrow();
    }

    private static int number(Map<String, Object> map, String key) {
        return ((Number) map.get(key)).intValue();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, String> stringMap(Object value) {
        return (Map<String, String>) value;
    }

    private static final class MutableFactsProvider implements PlatformProgressFactsProvider {
        private final Map<String, PlatformProgressFacts> values = new HashMap<>();
        private int calls;

        @Override
        public PlatformProgressFacts factsFor(String userId) {
            calls++;
            return values.getOrDefault(userId, PlatformProgressFacts.empty());
        }

        private void set(String userId, PlatformProgressFacts value) {
            values.put(userId, value);
        }

        private int calls() {
            return calls;
        }
    }
}
