package com.walkingrpg.backend.itemupgrade.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.expedition.application.ExpeditionContentActivation;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeCommand;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeDefinition;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeFingerprint;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeIdempotencyScope;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import com.walkingrpg.backend.itemupgrade.domain.ProcessedItemUpgradeCommand;
import com.walkingrpg.backend.itemupgrade.infrastructure.ItemUpgradeRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ItemUpgradeService {

    private final ItemUpgradeRepository repository;
    private final StarterItemUpgradeContent content;
    private final ExpeditionRepository expeditionRepository;
    private final EventResolutionRepository eventResolutionRepository;
    private final ExpeditionContentActivation contentActivation;
    private final Clock clock;

    public ItemUpgradeService(
            ItemUpgradeRepository repository,
            StarterItemUpgradeContent content,
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

    @Transactional
    public ItemUpgradeResult upgrade(ItemUpgradeCommand command) {
        repository.acquireLock(command.userId());
        ItemUpgradeIdempotencyScope scope = ItemUpgradeIdempotencyScope.from(
                command
        );
        String fingerprint = ItemUpgradeFingerprint.sha256(command);
        ProcessedItemUpgradeCommand processed = repository.findProcessed(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new ItemUpgradeIdempotencyConflictException();
            }
            return processed.result();
        }

        expeditionRepository.acquireLock(
                command.userId(),
                StarterExpeditionContent.EXPEDITION_ID
        );
        requireNoPendingResult(command.userId());
        ItemUpgradeDefinition definition = content.require(
                command.upgradeId(),
                contentActivation.activeContentVersion()
        );
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        return repository.upgrade(scope, fingerprint, definition, serverTime);
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
