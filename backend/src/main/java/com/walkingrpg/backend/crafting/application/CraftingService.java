package com.walkingrpg.backend.crafting.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.crafting.domain.CraftingCommand;
import com.walkingrpg.backend.crafting.domain.CraftingFingerprint;
import com.walkingrpg.backend.crafting.domain.CraftingIdempotencyScope;
import com.walkingrpg.backend.crafting.domain.CraftingRecipeDefinition;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
import com.walkingrpg.backend.crafting.domain.ProcessedCraftingCommand;
import com.walkingrpg.backend.crafting.infrastructure.CraftingRepository;
import com.walkingrpg.backend.expedition.application.ExpeditionContentActivation;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CraftingService {

    private final CraftingRepository repository;
    private final StarterCraftingContent content;
    private final ExpeditionRepository expeditionRepository;
    private final EventResolutionRepository eventResolutionRepository;
    private final ExpeditionContentActivation contentActivation;
    private final Clock clock;

    @Autowired
    public CraftingService(
            CraftingRepository repository,
            StarterCraftingContent content,
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventResolutionRepository,
            ExpeditionContentActivation contentActivation,
            Clock clock
    ) {
        this.repository = repository;
        this.content = content;
        this.expeditionRepository = expeditionRepository;
        this.eventResolutionRepository = eventResolutionRepository;
        this.contentActivation = contentActivation;
        this.clock = clock;
    }

    public CraftingService(
            CraftingRepository repository,
            StarterCraftingContent content,
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventResolutionRepository,
            Clock clock
    ) {
        this(
                repository,
                content,
                expeditionRepository,
                eventResolutionRepository,
                () -> StarterExpeditionContent
                        .PET_GUIDED_UNCHARTED_CONTENT_VERSION,
                clock
        );
    }

    @Transactional
    public CraftingResult craft(CraftingCommand command) {
        repository.acquireLock(command.userId());
        CraftingIdempotencyScope scope = CraftingIdempotencyScope.from(command);
        String fingerprint = CraftingFingerprint.sha256(command);
        ProcessedCraftingCommand processed = repository.findProcessed(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new CraftingIdempotencyConflictException();
            }
            return processed.result();
        }

        expeditionRepository.acquireLock(
                command.userId(),
                StarterExpeditionContent.EXPEDITION_ID
        );
        requireNoPendingResult(command.userId());

        CraftingRecipeDefinition recipe = content.require(
                command.recipeId(),
                contentActivation.activeContentVersion()
        );
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        return repository.createUniqueItem(
                scope,
                fingerprint,
                recipe,
                serverTime
        );
    }

    private void requireNoPendingResult(String userId) {
        eventResolutionRepository.findPendingResult(
                        userId,
                        StarterExpeditionContent.EXPEDITION_ID
                )
                .map(ProcessedEventResolution::result)
                .ifPresent(result -> {
                    throw new PendingEventResultException(
                            result.receiptId(),
                            result.eventId()
                    );
                });
    }
}
