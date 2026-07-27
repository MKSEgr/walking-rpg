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
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
import com.walkingrpg.backend.platform.api.PlatformSnapshotResponse;
import com.walkingrpg.backend.platform.infrastructure.InMemoryPlatformRepository;
import com.walkingrpg.backend.platform.payment.SandboxPaymentProvider;
import com.walkingrpg.backend.platform.progress.PlatformProgressFacts;
import com.walkingrpg.backend.platform.progress.PlatformProgressFactsProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
        service = new PlatformService(
                platformRepository,
                new PlatformContentCatalog(),
                factsProvider,
                economyService,
                new SandboxPaymentProvider(),
                JsonMapper.builder().findAndAddModules().build(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
    }

    @Test
    void shouldReturnStableReadOnlyInitialSnapshot() {
        PlatformSnapshotResponse first = service.getSnapshot("user-1");
        PlatformSnapshotResponse second = service.getSnapshot("user-1");

        assertEquals(first, second);
        assertEquals("chapter-1-v1", first.contentVersion());
        assertEquals(0, first.stateVersion());
        assertEquals("spark-v1", first.userState().get("activePetId"));
        assertEquals(3, list(first.userState(), "pets").size());
        assertEquals(18, first.content().get("chapterNodes"));
        assertTrue(platformRepository.findState("user-1").isEmpty());
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

    private static int number(Map<String, Object> map, String key) {
        return ((Number) map.get(key)).intValue();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, String> stringMap(Object value) {
        return (Map<String, String>) value;
    }

    private static final class MutableFactsProvider implements PlatformProgressFactsProvider {
        private final Map<String, PlatformProgressFacts> values = new HashMap<>();

        @Override
        public PlatformProgressFacts factsFor(String userId) {
            return values.getOrDefault(userId, PlatformProgressFacts.empty());
        }

        private void set(String userId, PlatformProgressFacts value) {
            values.put(userId, value);
        }
    }
}
