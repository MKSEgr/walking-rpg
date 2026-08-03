package com.walkingrpg.backend.platform.application;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import com.walkingrpg.backend.crafting.application.StarterCraftingContent;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
import com.walkingrpg.backend.platform.api.PlatformSnapshotResponse;
import com.walkingrpg.backend.platform.domain.PlatformCommandScope;
import com.walkingrpg.backend.platform.domain.PlatformPetProgress;
import com.walkingrpg.backend.platform.domain.PlatformUserState;
import com.walkingrpg.backend.platform.domain.ProcessedPlatformCommand;
import com.walkingrpg.backend.platform.domain.SquadView;
import com.walkingrpg.backend.platform.infrastructure.PlatformRepository;
import com.walkingrpg.backend.platform.payment.PaymentProvider;
import com.walkingrpg.backend.platform.payment.PaymentReceipt;
import com.walkingrpg.backend.platform.progress.PlatformProgressFacts;
import com.walkingrpg.backend.platform.progress.PlatformProgressFactsProvider;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.domain.PetProgressState;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlatformService {

    private static final String DEFAULT_PET_ID = "spark-v1";
    private static final String DEFAULT_COSMETIC_ID = "pilot-scarf";
    private static final String PURCHASE_COSMETIC_COMMAND = "PURCHASE_COSMETIC";
    private static final String LEGACY_BUY_COSMETIC_COMMAND = "BUY_COSMETIC";

    private final PlatformRepository repository;
    private final PlatformContentCatalog content;
    private final PlatformProgressFactsProvider progressFactsProvider;
    private final EconomyService economyService;
    private final PaymentProvider paymentProvider;
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final ProgressionService progressionService;

    @Autowired
    public PlatformService(
            PlatformRepository repository,
            PlatformContentCatalog content,
            PlatformProgressFactsProvider progressFactsProvider,
            EconomyService economyService,
            PaymentProvider paymentProvider,
            ObjectMapper objectMapper,
            Clock clock,
            ProgressionService progressionService
    ) {
        this.repository = repository;
        this.content = content;
        this.progressFactsProvider = progressFactsProvider;
        this.economyService = economyService;
        this.paymentProvider = paymentProvider;
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.progressionService = progressionService;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PlatformSnapshotResponse getSnapshot(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        PlatformProgressFacts facts = progressFactsProvider.factsFor(normalizedUserId);
        PlatformUserState state = repository.findState(normalizedUserId)
                .map(value -> reconcile(value, facts, normalizedUserId))
                .orElseGet(() -> initialState(normalizedUserId, facts));
        return snapshot(normalizedUserId, state, facts, now());
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public Map<String, Object> getContentBootstrap() {
        String activeContentVersion = repository.activeContentVersion();
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("contentVersion", activeContentVersion);
        response.put("content", content.publicCatalog(activeContentVersion));
        response.put("remoteConfig", effectiveRemoteConfig());
        response.put("serverTime", now());
        return response;
    }

    @Transactional
    public PlatformCommandResponse execute(
            String userId,
            PlatformCommandRequest request
    ) {
        String normalizedUserId = requireText(userId, "userId");
        String requestedCommandType = requireText(
                request.commandType(),
                "commandType"
        ).toUpperCase();
        String commandType = canonicalCommandType(requestedCommandType);
        Instant serverTime = now();
        repository.acquireUserLock(normalizedUserId);

        PlatformCommandScope scope = new PlatformCommandScope(
                normalizedUserId,
                commandType,
                request.idempotencyKey()
        );
        String fingerprint = PlatformCommandFingerprint.sha256(
                objectMapper,
                commandType,
                request.payload()
        );
        ProcessedPlatformCommand processed = repository.findProcessed(scope).orElse(null);
        if (processed != null) {
            return replay(processed, fingerprint);
        }
        if (PURCHASE_COSMETIC_COMMAND.equals(commandType)) {
            PlatformCommandScope legacyScope = new PlatformCommandScope(
                    normalizedUserId,
                    LEGACY_BUY_COSMETIC_COMMAND,
                    request.idempotencyKey()
            );
            ProcessedPlatformCommand legacy = repository.findProcessed(legacyScope)
                    .orElse(null);
            if (legacy != null) {
                String legacyFingerprint = PlatformCommandFingerprint.sha256(
                        objectMapper,
                        LEGACY_BUY_COSMETIC_COMMAND,
                        request.payload()
                );
                return replay(legacy, legacyFingerprint);
            }
        }
        if ("RECORD_COMPASS_IMPRESSION".equals(commandType)) {
            return executeCompassImpression(
                    normalizedUserId,
                    commandType,
                    request.payload(),
                    scope,
                    fingerprint,
                    serverTime
            );
        }
        requireProviderAvailability(commandType);

        PlatformProgressFacts factsBefore = progressFactsProvider.factsFor(normalizedUserId);
        PlatformUserState current = repository.lockOrCreateState(
                normalizedUserId,
                initialState(normalizedUserId, factsBefore),
                serverTime
        );
        current = reconcile(current, factsBefore, normalizedUserId);
        Mutation mutation = mutate(
                normalizedUserId,
                current,
                commandType,
                request.payload(),
                scope,
                factsBefore,
                serverTime
        );
        PlatformUserState updated = withDerivedAchievements(mutation.state());
        repository.saveState(normalizedUserId, updated, serverTime);
        repository.recordEvent(
                normalizedUserId,
                "platform_command_completed",
                serverTime,
                Map.of(
                        "commandType", commandType,
                        "stateVersion", updated.version()
                )
        );

        PlatformProgressFacts factsAfter = progressFactsProvider.factsFor(normalizedUserId);
        PlatformCommandResponse response = new PlatformCommandResponse(
                requestedCommandType,
                scope.idempotencyKey(),
                mutation.message(),
                updated.version(),
                snapshot(normalizedUserId, updated, factsAfter, serverTime),
                serverTime
        );
        String responseJson = writeResponse(response);
        PlatformCommandResponse canonicalResponse = readResponse(responseJson);
        saveProcessedWithCompatibilityAliases(
                scope,
                request.payload(),
                fingerprint,
                responseJson,
                serverTime
        );
        return canonicalResponse;
    }

    private void saveProcessedWithCompatibilityAliases(
            PlatformCommandScope canonicalScope,
            Map<String, Object> payload,
            String canonicalFingerprint,
            String responseJson,
            Instant createdAt
    ) {
        repository.saveProcessed(
                canonicalScope,
                new ProcessedPlatformCommand(canonicalFingerprint, responseJson),
                createdAt
        );
        if (!PURCHASE_COSMETIC_COMMAND.equals(canonicalScope.commandType())) {
            return;
        }

        PlatformCommandScope legacyScope = new PlatformCommandScope(
                canonicalScope.userId(),
                LEGACY_BUY_COSMETIC_COMMAND,
                canonicalScope.idempotencyKey()
        );
        String legacyFingerprint = PlatformCommandFingerprint.sha256(
                objectMapper,
                LEGACY_BUY_COSMETIC_COMMAND,
                payload
        );
        repository.saveProcessed(
                legacyScope,
                new ProcessedPlatformCommand(legacyFingerprint, responseJson),
                createdAt
        );
    }

    private PlatformCommandResponse replay(
            ProcessedPlatformCommand processed,
            String expectedFingerprint
    ) {
        if (!processed.requestFingerprint().equals(expectedFingerprint)) {
            throw new PlatformIdempotencyConflictException();
        }
        return withEffectiveRemoteConfig(readResponse(processed.responseJson()));
    }

    private String canonicalCommandType(String commandType) {
        return LEGACY_BUY_COSMETIC_COMMAND.equals(commandType)
                ? PURCHASE_COSMETIC_COMMAND
                : commandType;
    }

    private Mutation mutate(
            String userId,
            PlatformUserState state,
            String commandType,
            Map<String, Object> payload,
            PlatformCommandScope scope,
            PlatformProgressFacts facts,
            Instant occurredAt
    ) {
        return switch (commandType) {
            case "COMPLETE_ONBOARDING_STEP" -> completeOnboarding(state, payload);
            case "SELECT_PET" -> selectPet(state, payload);
            case "EVOLVE_PET" -> evolvePet(userId, state, payload, occurredAt);
            case "UNLOCK_SKILL" -> unlockSkill(state, payload);
            case "CLAIM_QUEST" -> claimQuest(
                    userId, state, payload, facts, occurredAt
            );
            case "ADVANCE_WEEKLY_ROUTE" -> advanceWeeklyRoute(
                    userId, state, payload, scope, occurredAt
            );
            case "CREATE_SQUAD" -> createSquad(userId, state, payload, scope, occurredAt);
            case "JOIN_SQUAD" -> joinSquad(userId, state, payload, occurredAt);
            case "LEAVE_SQUAD" -> leaveSquad(userId, state);
            case PURCHASE_COSMETIC_COMMAND -> purchaseCosmetic(
                    userId, state, payload, scope, occurredAt
            );
            case "EQUIP_COSMETIC" -> equipCosmetic(state, payload);
            case "CLAIM_SEASON_REWARD" -> claimSeasonReward(state, payload);
            case "RECORD_EXPERIMENT_EXPOSURE" -> recordExperimentExposure(
                    userId, state, payload, occurredAt
            );
            default -> throw new PlatformValidationException(
                    "Неизвестный commandType", "commandType"
            );
        };
    }

    private PlatformCommandResponse executeCompassImpression(
            String userId,
            String commandType,
            Map<String, Object> payload,
            PlatformCommandScope scope,
            String fingerprint,
            Instant serverTime
    ) {
        PlatformProgressFacts facts = progressFactsProvider.factsFor(userId);
        PlatformUserState state = repository.findState(userId)
                .orElseGet(() -> initialState(userId, facts));
        recordCompassImpression(userId, payload, serverTime);
        repository.recordEvent(
                userId,
                "platform_command_completed",
                serverTime,
                Map.of(
                        "commandType", commandType,
                        "stateVersion", state.version()
                )
        );

        PlatformCommandResponse response = new PlatformCommandResponse(
                commandType,
                scope.idempotencyKey(),
                "Показ компаса зарегистрирован",
                state.version(),
                snapshot(userId, state, facts, serverTime),
                serverTime
        );
        String responseJson = writeResponse(response);
        PlatformCommandResponse canonicalResponse = readResponse(responseJson);
        repository.saveProcessed(
                scope,
                new ProcessedPlatformCommand(fingerprint, responseJson),
                serverTime
        );
        return canonicalResponse;
    }

    private Mutation completeOnboarding(
            PlatformUserState state,
            Map<String, Object> payload
    ) {
        String stepId = payloadText(payload, "stepId");
        if (!content.onboardingSteps().contains(stepId)) {
            throw new PlatformValidationException("Неизвестный шаг onboarding", "stepId");
        }
        Set<String> completed = new LinkedHashSet<>(state.completedOnboardingSteps());
        if (!completed.add(stepId)) {
            return new Mutation(state, "Шаг onboarding уже завершён");
        }
        return new Mutation(withOnboarding(state, completed), "Шаг onboarding завершён");
    }

    private Mutation selectPet(PlatformUserState state, Map<String, Object> payload) {
        String petId = payloadText(payload, "petId");
        content.requirePet(petId);
        Set<String> onboarding = new LinkedHashSet<>(state.completedOnboardingSteps());
        boolean onboardingChanged = onboarding.add("pet-selection");
        if (petId.equals(state.activePetId()) && !onboardingChanged) {
            return new Mutation(state, "Питомец уже активен");
        }
        PlatformUserState updated = changed(
                state,
                petId,
                state.pets(),
                onboarding,
                state.unlockedSkills(),
                state.claimedQuests(),
                state.achievements(),
                state.seasonXp(),
                state.weeklyRouteProgress(),
                state.squadId(),
                state.ownedCosmetics(),
                state.activeCosmeticId()
        );
        return new Mutation(
                updated,
                petId.equals(state.activePetId())
                        ? "Питомец выбран"
                        : "Активный питомец изменён"
        );
    }

    private Mutation evolvePet(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            Instant occurredAt
    ) {
        String petId = payloadText(payload, "petId");
        PlatformContentCatalog.PetDefinition definition = content.requirePet(petId);
        PlatformPetProgress progress = state.pets().get(petId);
        if (progress == null) {
            throw new PlatformStateConflictException("Питомец не открыт");
        }
        if (progress.evolutionStage() > 0) {
            return new Mutation(state, "Питомец уже эволюционировал");
        }
        if (progress.bond() < definition.evolutionBond()) {
            throw new PlatformStateConflictException(
                    "Недостаточно связи для эволюции",
                    Map.of(
                            "currentBond", progress.bond(),
                            "requiredBond", definition.evolutionBond()
                    )
            );
        }
        Map<String, PlatformPetProgress> pets = new LinkedHashMap<>(state.pets());
        PlatformPetProgress evolved = progress.evolve();
        PetProgressState canonical = progressionService.synchronizeAndReward(
                userId,
                petId,
                evolved.level(),
                evolved.bond(),
                0,
                occurredAt
        );
        pets.put(petId, new PlatformPetProgress(
                canonical.level(),
                canonical.bond(),
                evolved.evolutionStage()
        ));
        return new Mutation(withPets(state, pets), "Питомец эволюционировал");
    }

    private Mutation unlockSkill(PlatformUserState state, Map<String, Object> payload) {
        String skillId = payloadText(payload, "skillId");
        PlatformContentCatalog.SkillDefinition skill = content.requireSkill(skillId);
        if (state.seasonXp() < skill.requiredSeasonXp()) {
            throw new PlatformStateConflictException(
                    "Недостаточно сезонного опыта для навыка",
                    Map.of(
                            "currentSeasonXp", state.seasonXp(),
                            "requiredSeasonXp", skill.requiredSeasonXp()
                    )
            );
        }
        Set<String> skills = new LinkedHashSet<>(state.unlockedSkills());
        if (!skills.add(skillId)) {
            return new Mutation(state, "Навык уже открыт");
        }
        return new Mutation(withSkills(state, skills), "Навык пилота открыт");
    }

    private Mutation claimQuest(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            PlatformProgressFacts facts,
            Instant occurredAt
    ) {
        String questId = payloadText(payload, "questId");
        PlatformContentCatalog.QuestDefinition quest = content.requireQuest(questId);
        if (state.claimedQuests().contains(questId)) {
            return new Mutation(state, "Награда задания уже получена");
        }
        long questProgress = questProgress(quest, facts);
        if (questProgress < quest.target()) {
            throw new PlatformStateConflictException(
                    "Условия задания ещё не выполнены",
                    Map.of("progress", questProgress, "target", quest.target())
            );
        }
        Set<String> quests = new LinkedHashSet<>(state.claimedQuests());
        quests.add(questId);
        Map<String, PlatformPetProgress> pets = new LinkedHashMap<>(state.pets());
        PlatformPetProgress activePetProgress = pets.get(state.activePetId());
        PetProgressState canonical = progressionService.synchronizeAndReward(
                userId,
                state.activePetId(),
                activePetProgress.level(),
                activePetProgress.bond(),
                quest.petBondReward(),
                occurredAt
        );
        pets.put(state.activePetId(), new PlatformPetProgress(
                canonical.level(),
                canonical.bond(),
                activePetProgress.evolutionStage()
        ));
        PlatformUserState rewarded = withQuestReward(
                state,
                pets,
                quests,
                Math.addExact(state.seasonXp(), quest.seasonXpReward())
        );
        return new Mutation(rewarded, "Награда задания получена");
    }

    private Mutation advanceWeeklyRoute(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            PlatformCommandScope scope,
            Instant occurredAt
    ) {
        if (!featureEnabled("weeklyRouteEnabled")) {
            throw new PlatformStateConflictException("Недельный маршрут отключён конфигурацией");
        }
        int requiredEnergy = configInt("weeklyRouteEnergy", 120, 10, 10_000);
        int energyToSpend = payloadInt(payload, "energyToSpend");
        if (energyToSpend <= 0) {
            throw new PlatformValidationException(
                    "energyToSpend должна быть положительной", "energyToSpend"
            );
        }
        int remaining = requiredEnergy - state.weeklyRouteProgress();
        if (remaining <= 0) {
            return new Mutation(state, "Недельный маршрут уже завершён");
        }
        if (energyToSpend > remaining) {
            throw new PlatformStateConflictException(
                    "energyToSpend превышает остаток недельного маршрута",
                    Map.of("remainingEnergy", remaining)
            );
        }
        economyService.debitEnergy(
                userId,
                energyToSpend,
                "WEEKLY_ROUTE_PROGRESS",
                "WEEKLY_ROUTE_ADVANCE",
                "weekly:" + scope.idempotencyKey(),
                occurredAt
        );
        int progress = state.weeklyRouteProgress() + energyToSpend;
        int seasonXp = state.seasonXp() + (progress == requiredEnergy ? 120 : 0);
        return new Mutation(
                withWeeklyRoute(state, progress, seasonXp),
                progress == requiredEnergy
                        ? "Недельный маршрут завершён"
                        : "Недельный маршрут продвинут"
        );
    }

    private Mutation createSquad(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            PlatformCommandScope scope,
            Instant occurredAt
    ) {
        if (state.squadId() != null) {
            throw new PlatformStateConflictException("Пользователь уже состоит в отряде");
        }
        String name = payloadText(payload, "name");
        if (name.length() > 120) {
            throw new PlatformValidationException("Название отряда слишком длинное", "name");
        }
        String squadId = UUID.nameUUIDFromBytes(
                (userId + ":" + scope.idempotencyKey()).getBytes(StandardCharsets.UTF_8)
        ).toString();
        repository.createSquad(squadId, name, userId, occurredAt);
        return new Mutation(withSquad(state, squadId), "Отряд создан");
    }

    private Mutation joinSquad(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            Instant occurredAt
    ) {
        if (state.squadId() != null) {
            throw new PlatformStateConflictException("Пользователь уже состоит в отряде");
        }
        String squadId = payloadText(payload, "squadId");
        repository.joinSquad(squadId, userId, occurredAt);
        return new Mutation(withSquad(state, squadId), "Пользователь вступил в отряд");
    }

    private Mutation leaveSquad(String userId, PlatformUserState state) {
        if (state.squadId() == null) {
            return new Mutation(state, "Пользователь не состоит в отряде");
        }
        repository.leaveSquad(state.squadId(), userId);
        return new Mutation(withSquad(state, null), "Пользователь покинул отряд");
    }

    private Mutation purchaseCosmetic(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            PlatformCommandScope scope,
            Instant occurredAt
    ) {
        String cosmeticId = payloadText(payload, "cosmeticId");
        PlatformContentCatalog.CosmeticDefinition cosmetic = content.requireCosmetic(cosmeticId);
        if (state.ownedCosmetics().contains(cosmeticId)) {
            return new Mutation(state, "Косметика уже приобретена");
        }
        PaymentReceipt receipt = paymentProvider.purchase(
                userId,
                cosmeticId,
                cosmetic.sandboxPrice(),
                scope.idempotencyKey(),
                occurredAt
        );
        repository.savePaymentIntent(
                userId,
                cosmeticId,
                cosmetic.sandboxPrice(),
                scope.idempotencyKey(),
                receipt,
                occurredAt
        );
        Set<String> cosmetics = new LinkedHashSet<>(state.ownedCosmetics());
        cosmetics.add(cosmeticId);
        return new Mutation(
                withCosmetics(state, cosmetics, state.activeCosmeticId()),
                "Sandbox-покупка выполнена"
        );
    }

    private Mutation equipCosmetic(PlatformUserState state, Map<String, Object> payload) {
        String cosmeticId = payloadText(payload, "cosmeticId");
        content.requireCosmetic(cosmeticId);
        if (!state.ownedCosmetics().contains(cosmeticId)) {
            throw new PlatformStateConflictException("Косметика не приобретена");
        }
        if (cosmeticId.equals(state.activeCosmeticId())) {
            return new Mutation(state, "Косметика уже экипирована");
        }
        return new Mutation(
                withCosmetics(state, state.ownedCosmetics(), cosmeticId),
                "Косметика экипирована"
        );
    }

    private Mutation claimSeasonReward(PlatformUserState state, Map<String, Object> payload) {
        int level = payloadInt(payload, "level");
        if (level <= 0 || level > 10) {
            throw new PlatformValidationException("Уровень сезона должен быть от 1 до 10", "level");
        }
        int requiredXp = level * 100;
        if (state.seasonXp() < requiredXp) {
            throw new PlatformStateConflictException(
                    "Недостаточно сезонного опыта",
                    Map.of("currentSeasonXp", state.seasonXp(), "requiredSeasonXp", requiredXp)
            );
        }
        String achievementId = "season-reward-" + level;
        Set<String> achievements = new LinkedHashSet<>(state.achievements());
        if (!achievements.add(achievementId)) {
            return new Mutation(state, "Награда сезона уже получена");
        }
        return new Mutation(withAchievements(state, achievements), "Награда сезона получена");
    }

    private Mutation recordExperimentExposure(
            String userId,
            PlatformUserState state,
            Map<String, Object> payload,
            Instant occurredAt
    ) {
        String experimentId = payloadText(payload, "experimentId");
        String variant = payloadText(payload, "variant");
        String assigned = state.experimentAssignments().get(experimentId);
        if (assigned == null) {
            throw new PlatformValidationException("Неизвестный experimentId", "experimentId");
        }
        if (!assigned.equals(variant)) {
            throw new PlatformStateConflictException(
                    "Переданный variant не совпадает с назначением",
                    Map.of("assignedVariant", assigned)
            );
        }
        repository.recordEvent(userId, "experiment_exposure", occurredAt, Map.of(
                "experimentId", experimentId,
                "variant", variant
        ));
        return new Mutation(state, "Exposure зарегистрирован");
    }

    private void recordCompassImpression(
            String userId,
            Map<String, Object> payload,
            Instant occurredAt
    ) {
        String impression = payloadText(payload, "impression").toUpperCase();
        String contentVersion = payloadText(payload, "contentVersion");
        if (!StarterExpeditionContent.LEGACY_CONTENT_VERSION.equals(contentVersion)
                && !StarterExpeditionContent.CONTENT_VERSION.equals(contentVersion)) {
            throw new PlatformValidationException(
                    "Неизвестная версия контента для impression",
                    "contentVersion"
            );
        }

        Map<String, Object> attributes = new LinkedHashMap<>();
        attributes.put("contractVersion", "compass-beta-funnel-v1");
        attributes.put("contentVersion", contentVersion);
        String eventName;
        switch (impression) {
            case "RECIPE_MISSING_MATERIALS", "RECIPE_READY", "RECIPE_CRAFTED" -> {
                eventName = "compass_recipe_impression";
                attributes.put(
                        "recipeId",
                        StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID
                );
                attributes.put("status", impression.substring("RECIPE_".length()));
            }
            case "ROUTE_LOCKED", "ROUTE_AVAILABLE" -> {
                if (!StarterExpeditionContent.CONTENT_VERSION.equals(contentVersion)) {
                    throw new PlatformValidationException(
                            "Резонансный маршрут отсутствует в этой версии контента",
                            "contentVersion"
                    );
                }
                if (!StarterExpeditionContent.CONTENT_VERSION.equals(
                        repository.activeContentVersion()
                )) {
                    throw new PlatformValidationException(
                            "Резонансный маршрут ещё не активирован",
                            "contentVersion"
                    );
                }
                eventName = "compass_route_impression";
                attributes.put("eventId", StarterExpeditionContent.MIRROR_DELTA_EVENT_ID);
                attributes.put("choiceId", StarterExpeditionContent.RESONANCE_ROUTE_CHOICE_ID);
                attributes.put("availability", impression.substring("ROUTE_".length()));
            }
            default -> throw new PlatformValidationException(
                    "Неизвестный compass impression",
                    "impression"
            );
        }
        repository.recordEvent(userId, eventName, occurredAt, Map.copyOf(attributes));
    }

    private PlatformUserState withDerivedAchievements(PlatformUserState state) {
        Set<String> achievements = new LinkedHashSet<>(state.achievements());
        if (state.completedOnboardingSteps().containsAll(content.onboardingSteps())) {
            achievements.add("onboarding-complete");
        }
        if (state.pets().values().stream().anyMatch(pet -> pet.bond() >= 50)) {
            achievements.add("pet-friend");
        }
        if (state.unlockedSkills().size() >= 2) {
            achievements.add("skill-apprentice");
        }
        if (state.claimedQuests().size() >= 2) {
            achievements.add("quest-runner");
        }
        int weeklyRequired = configInt("weeklyRouteEnergy", 120, 10, 10_000);
        if (state.weeklyRouteProgress() >= weeklyRequired) {
            achievements.add("weekly-route-complete");
        }
        if (state.squadId() != null) {
            achievements.add("squad-member");
        }
        if (state.ownedCosmetics().size() > 1) {
            achievements.add("first-cosmetic");
        }
        if (state.seasonXp() >= 300) {
            achievements.add("season-level-3");
        }
        if (achievements.equals(state.achievements())) {
            return state;
        }
        return replace(
                state,
                state.activePetId(),
                state.pets(),
                state.completedOnboardingSteps(),
                state.unlockedSkills(),
                state.claimedQuests(),
                achievements,
                state.seasonXp(),
                state.weeklyRouteProgress(),
                state.squadId(),
                state.ownedCosmetics(),
                state.activeCosmeticId(),
                state.experimentAssignments(),
                state.version() + 1
        );
    }

    private PlatformUserState initialState(String userId, PlatformProgressFacts facts) {
        Map<String, PlatformPetProgress> pets = new LinkedHashMap<>();
        content.pets().forEach(definition -> pets.put(
                definition.petId(),
                new PlatformPetProgress(
                        1,
                        facts.petBond(definition.petId(), definition.initialBond()),
                        0
                )
        ));
        Map<String, String> assignments = new LinkedHashMap<>();
        content.experiments().forEach(experiment -> assignments.put(
                experiment.experimentId(),
                content.variantFor(userId, experiment)
        ));
        return new PlatformUserState(
                PlatformUserState.CURRENT_SCHEMA_VERSION,
                DEFAULT_PET_ID,
                pets,
                Set.of(),
                Set.of(),
                Set.of(),
                Set.of(),
                0,
                0,
                facts.squadId(),
                Set.of(DEFAULT_COSMETIC_ID),
                DEFAULT_COSMETIC_ID,
                assignments,
                0
        );
    }

    private PlatformUserState reconcile(
            PlatformUserState state,
            PlatformProgressFacts facts,
            String userId
    ) {
        Map<String, PlatformPetProgress> pets = new LinkedHashMap<>(state.pets());
        for (PlatformContentCatalog.PetDefinition definition : content.pets()) {
            pets.putIfAbsent(definition.petId(), new PlatformPetProgress(1, 0, 0));
        }
        for (PlatformContentCatalog.PetDefinition definition : content.pets()) {
            PlatformPetProgress progress = pets.get(definition.petId());
            int factBond = facts.petBond(definition.petId(), definition.initialBond());
            if (progress != null && factBond > progress.bond()) {
                pets.put(definition.petId(), new PlatformPetProgress(
                        progress.level(), factBond, progress.evolutionStage()
                ));
            }
        }
        Map<String, String> assignments = new LinkedHashMap<>(state.experimentAssignments());
        content.experiments().forEach(experiment -> assignments.putIfAbsent(
                experiment.experimentId(),
                content.variantFor(userId, experiment)
        ));
        Set<String> cosmetics = new LinkedHashSet<>(state.ownedCosmetics());
        cosmetics.add(DEFAULT_COSMETIC_ID);
        String activePet = pets.containsKey(state.activePetId())
                ? state.activePetId()
                : DEFAULT_PET_ID;
        String activeCosmetic = state.activeCosmeticId() != null
                && cosmetics.contains(state.activeCosmeticId())
                ? state.activeCosmeticId()
                : DEFAULT_COSMETIC_ID;
        return replace(
                state,
                activePet,
                pets,
                state.completedOnboardingSteps(),
                state.unlockedSkills(),
                state.claimedQuests(),
                state.achievements(),
                state.seasonXp(),
                state.weeklyRouteProgress(),
                facts.squadId(),
                cosmetics,
                activeCosmetic,
                assignments,
                state.version()
        );
    }

    private PlatformSnapshotResponse snapshot(
            String userId,
            PlatformUserState state,
            PlatformProgressFacts facts,
            Instant serverTime
    ) {
        Map<String, Object> userState = new LinkedHashMap<>();
        userState.put("activePetId", state.activePetId());
        userState.put("pets", petViews(state));
        userState.put("completedOnboardingSteps", state.completedOnboardingSteps());
        userState.put("onboardingComplete",
                state.completedOnboardingSteps().containsAll(content.onboardingSteps()));
        userState.put("unlockedSkills", state.unlockedSkills());
        userState.put("quests", questViews(state, facts));
        userState.put("claimedQuests", state.claimedQuests());
        userState.put("achievements", state.achievements());
        userState.put("seasonXp", state.seasonXp());
        userState.put("seasonLevel", state.seasonXp() / 100 + 1);
        userState.put("weeklyRouteProgress", state.weeklyRouteProgress());
        userState.put("weeklyRouteRequiredEnergy",
                configInt("weeklyRouteEnergy", 120, 10, 10_000));
        userState.put("squad", squadView(userId, state));
        userState.put("ownedCosmetics", state.ownedCosmetics());
        userState.put("activeCosmeticId", state.activeCosmeticId());
        userState.put("experimentAssignments", state.experimentAssignments());
        userState.put("resolvedEventCount", facts.resolvedEventCount());
        userState.put("totalAcceptedSteps", facts.totalAcceptedSteps());
        userState.put(
                "hasSuccessfulActivitySync",
                facts.hasSuccessfulActivitySync()
        );

        String activeContentVersion = repository.activeContentVersion();
        return new PlatformSnapshotResponse(
                activeContentVersion,
                state.version(),
                userState,
                content.publicCatalog(activeContentVersion),
                effectiveRemoteConfig(),
                serverTime
        );
    }

    private List<Map<String, Object>> petViews(PlatformUserState state) {
        List<Map<String, Object>> views = new ArrayList<>();
        for (PlatformContentCatalog.PetDefinition definition : content.pets()) {
            PlatformPetProgress progress = state.pets().get(definition.petId());
            Map<String, Object> view = new LinkedHashMap<>();
            view.put("petId", definition.petId());
            view.put("name", progress.evolutionStage() > 0
                    ? definition.evolvedName()
                    : definition.name());
            view.put("species", definition.species());
            view.put("trait", definition.trait());
            view.put("level", progress.level());
            view.put("bond", progress.bond());
            view.put("evolutionStage", progress.evolutionStage());
            view.put("evolutionBond", definition.evolutionBond());
            view.put("active", definition.petId().equals(state.activePetId()));
            views.add(Map.copyOf(view));
        }
        return List.copyOf(views);
    }

    private List<Map<String, Object>> questViews(
            PlatformUserState state,
            PlatformProgressFacts facts
    ) {
        List<Map<String, Object>> views = new ArrayList<>();
        for (PlatformContentCatalog.QuestDefinition quest : content.quests()) {
            long progress = questProgress(quest, facts);
            Map<String, Object> view = new LinkedHashMap<>();
            view.put("questId", quest.questId());
            view.put("name", quest.name());
            view.put("metric", quest.metric().name());
            view.put("progress", Math.min(progress, quest.target()));
            view.put("target", quest.target());
            view.put("ready", progress >= quest.target());
            view.put("claimed", state.claimedQuests().contains(quest.questId()));
            view.put("seasonXpReward", quest.seasonXpReward());
            view.put("petBondReward", quest.petBondReward());
            views.add(Map.copyOf(view));
        }
        return List.copyOf(views);
    }

    private Object squadView(String userId, PlatformUserState state) {
        if (state.squadId() == null) {
            return null;
        }
        Optional<SquadView> squad = repository.findSquadForUser(userId);
        return squad.<Object>map(value -> Map.of(
                "squadId", value.squadId(),
                "name", value.name(),
                "ownerUserId", value.ownerUserId(),
                "memberUserIds", value.memberUserIds()
        )).orElse(null);
    }

    private long questProgress(
            PlatformContentCatalog.QuestDefinition quest,
            PlatformProgressFacts facts
    ) {
        return switch (quest.metric()) {
            case TOTAL_ACCEPTED_STEPS -> facts.totalAcceptedSteps();
            case RESOLVED_EVENTS -> facts.resolvedEventCount();
            case SQUAD_MEMBERSHIP -> facts.inSquad() ? 1 : 0;
        };
    }

    private boolean featureEnabled(String key) {
        Object value = effectiveRemoteConfig().get(key);
        return !(value instanceof Boolean enabled) || enabled;
    }

    private int configInt(String key, int defaultValue, int min, int max) {
        return boundedConfigInteger(
                effectiveRemoteConfig().get(key),
                defaultValue,
                min,
                max
        );
    }

    private int boundedConfigInteger(
            Object value,
            int defaultValue,
            int min,
            int max
    ) {
        Integer raw = PlatformNumbers.integerOrNull(value);
        if (raw == null) {
            return defaultValue;
        }
        return raw < min || raw > max ? defaultValue : raw;
    }

    private void requireProviderAvailability(String commandType) {
        if (!isPurchaseCommand(commandType)) {
            return;
        }
        if (!paymentProvider.isAvailable()
                || !featureEnabled("sandboxPaymentsEnabled")) {
            throw new PlatformStateConflictException(
                    "Покупки недоступны в текущей конфигурации"
            );
        }
    }

    private boolean isPurchaseCommand(String commandType) {
        return PURCHASE_COSMETIC_COMMAND.equals(commandType);
    }

    private Map<String, Object> effectiveRemoteConfig() {
        Map<String, Object> activeConfig = repository.activeRemoteConfig();
        return withEffectiveProviderCapabilities(activeConfig, activeConfig);
    }

    private Map<String, Object> withEffectiveProviderCapabilities(
            Map<String, Object> responseConfig,
            Map<String, Object> activeConfig
    ) {
        Map<String, Object> config = new LinkedHashMap<>();
        if (responseConfig != null) {
            responseConfig.forEach((key, value) -> {
                if (key != null && value != null) {
                    config.put(key, value);
                }
            });
        }
        config.put(
                "sandboxPaymentsEnabled",
                paymentProvider.isAvailable()
                        && activeConfig != null
                        && Boolean.TRUE.equals(activeConfig.get("sandboxPaymentsEnabled"))
        );
        config.put("backgroundHealthSyncEnabled", false);
        config.put(
                "activityRetentionDays",
                boundedConfigInteger(
                        config.get("activityRetentionDays"),
                        30,
                        1,
                        3650
                )
        );
        config.put(
                "weeklyRouteEnergy",
                boundedConfigInteger(
                        config.get("weeklyRouteEnergy"),
                        120,
                        10,
                        10_000
                )
        );
        return Map.copyOf(config);
    }

    private PlatformCommandResponse withEffectiveRemoteConfig(
            PlatformCommandResponse response
    ) {
        PlatformSnapshotResponse original = response.snapshot();
        Map<String, Object> activeConfig = repository.activeRemoteConfig();
        PlatformSnapshotResponse snapshot = new PlatformSnapshotResponse(
                original.contentVersion(),
                original.stateVersion(),
                original.userState(),
                original.content(),
                withEffectiveProviderCapabilities(
                        original.remoteConfig(),
                        activeConfig
                ),
                original.serverTime()
        );
        return new PlatformCommandResponse(
                response.commandType(),
                response.idempotencyKey(),
                response.message(),
                response.stateVersion(),
                snapshot,
                response.serverTime()
        );
    }

    private PlatformCommandResponse readResponse(String json) {
        try {
            return objectMapper.readValue(json, PlatformCommandResponse.class);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Некорректный saved platform response", exception);
        }
    }

    private String writeResponse(PlatformCommandResponse response) {
        try {
            return objectMapper.writeValueAsString(response);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Не удалось сохранить platform response", exception);
        }
    }

    private String payloadText(Map<String, Object> payload, String field) {
        Object value = payload.get(field);
        if (!(value instanceof String text) || text.isBlank()) {
            throw new PlatformValidationException("Поле обязательно", field);
        }
        return text.trim();
    }

    private int payloadInt(Map<String, Object> payload, String field) {
        return PlatformNumbers.requireInteger(payload.get(field), field);
    }

    private Instant now() {
        return Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
    }

    private String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new PlatformValidationException("Поле обязательно", field);
        }
        return value.trim();
    }

    private PlatformUserState withPets(
            PlatformUserState state,
            Map<String, PlatformPetProgress> pets
    ) {
        return changed(state, state.activePetId(), pets, state.completedOnboardingSteps(),
                state.unlockedSkills(), state.claimedQuests(), state.achievements(),
                state.seasonXp(), state.weeklyRouteProgress(), state.squadId(),
                state.ownedCosmetics(), state.activeCosmeticId());
    }

    private PlatformUserState withOnboarding(PlatformUserState state, Set<String> onboarding) {
        return changed(state, state.activePetId(), state.pets(), onboarding,
                state.unlockedSkills(), state.claimedQuests(), state.achievements(),
                state.seasonXp(), state.weeklyRouteProgress(), state.squadId(),
                state.ownedCosmetics(), state.activeCosmeticId());
    }

    private PlatformUserState withSkills(PlatformUserState state, Set<String> skills) {
        return changed(state, state.activePetId(), state.pets(),
                state.completedOnboardingSteps(), skills, state.claimedQuests(),
                state.achievements(), state.seasonXp(), state.weeklyRouteProgress(),
                state.squadId(), state.ownedCosmetics(), state.activeCosmeticId());
    }

    private PlatformUserState withQuestReward(
            PlatformUserState state,
            Map<String, PlatformPetProgress> pets,
            Set<String> quests,
            int seasonXp
    ) {
        return changed(state, state.activePetId(), pets, state.completedOnboardingSteps(),
                state.unlockedSkills(), quests, state.achievements(), seasonXp,
                state.weeklyRouteProgress(), state.squadId(), state.ownedCosmetics(),
                state.activeCosmeticId());
    }

    private PlatformUserState withWeeklyRoute(
            PlatformUserState state,
            int weeklyProgress,
            int seasonXp
    ) {
        return changed(state, state.activePetId(), state.pets(),
                state.completedOnboardingSteps(), state.unlockedSkills(),
                state.claimedQuests(), state.achievements(), seasonXp, weeklyProgress,
                state.squadId(), state.ownedCosmetics(), state.activeCosmeticId());
    }

    private PlatformUserState withSquad(PlatformUserState state, String squadId) {
        return changed(state, state.activePetId(), state.pets(),
                state.completedOnboardingSteps(), state.unlockedSkills(),
                state.claimedQuests(), state.achievements(), state.seasonXp(),
                state.weeklyRouteProgress(), squadId, state.ownedCosmetics(),
                state.activeCosmeticId());
    }

    private PlatformUserState withCosmetics(
            PlatformUserState state,
            Set<String> cosmetics,
            String activeCosmeticId
    ) {
        return changed(state, state.activePetId(), state.pets(),
                state.completedOnboardingSteps(), state.unlockedSkills(),
                state.claimedQuests(), state.achievements(), state.seasonXp(),
                state.weeklyRouteProgress(), state.squadId(), cosmetics,
                activeCosmeticId);
    }

    private PlatformUserState withAchievements(
            PlatformUserState state,
            Set<String> achievements
    ) {
        return changed(state, state.activePetId(), state.pets(),
                state.completedOnboardingSteps(), state.unlockedSkills(),
                state.claimedQuests(), achievements, state.seasonXp(),
                state.weeklyRouteProgress(), state.squadId(), state.ownedCosmetics(),
                state.activeCosmeticId());
    }

    private PlatformUserState changed(
            PlatformUserState state,
            String activePetId,
            Map<String, PlatformPetProgress> pets,
            Set<String> onboarding,
            Set<String> skills,
            Set<String> quests,
            Set<String> achievements,
            int seasonXp,
            int weeklyProgress,
            String squadId,
            Set<String> cosmetics,
            String activeCosmeticId
    ) {
        return replace(state, activePetId, pets, onboarding, skills, quests, achievements,
                seasonXp, weeklyProgress, squadId, cosmetics, activeCosmeticId,
                state.experimentAssignments(), state.version() + 1);
    }

    private PlatformUserState replace(
            PlatformUserState state,
            String activePetId,
            Map<String, PlatformPetProgress> pets,
            Set<String> onboarding,
            Set<String> skills,
            Set<String> quests,
            Set<String> achievements,
            int seasonXp,
            int weeklyProgress,
            String squadId,
            Set<String> cosmetics,
            String activeCosmeticId,
            Map<String, String> experiments,
            long version
    ) {
        return new PlatformUserState(
                state.schemaVersion(),
                activePetId,
                pets,
                onboarding,
                skills,
                quests,
                achievements,
                seasonXp,
                weeklyProgress,
                squadId,
                cosmetics,
                activeCosmeticId,
                experiments,
                version
        );
    }

    private record Mutation(PlatformUserState state, String message) {
    }
}
