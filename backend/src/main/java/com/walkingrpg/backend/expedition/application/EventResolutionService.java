package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionFingerprint;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.domain.ProgressionRewardResult;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EventResolutionService {

    private final ExpeditionRepository expeditionRepository;
    private final EventResolutionRepository eventRepository;
    private final ProgressionService progressionService;
    private final StarterExpeditionContent content;
    private final Clock clock;

    public EventResolutionService(
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventRepository,
            ProgressionService progressionService,
            StarterExpeditionContent content,
            Clock clock
    ) {
        this.expeditionRepository = expeditionRepository;
        this.eventRepository = eventRepository;
        this.progressionService = progressionService;
        this.content = content;
        this.clock = clock;
    }

    @Transactional
    public EventResolutionResult resolve(EventResolutionCommand command) {
        ExpeditionDefinition definition = content.requireEvent(command.eventId());
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        expeditionRepository.acquireLock(command.userId(), definition.expeditionId());

        EventIdempotencyScope scope = EventIdempotencyScope.from(command);
        String fingerprint = EventResolutionFingerprint.sha256(command);
        ProcessedEventResolution processed = eventRepository.findProcessed(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new EventResolutionIdempotencyConflictException();
            }
            return processed.result();
        }

        ExpeditionProgressState current = expeditionRepository.findState(
                command.userId(),
                definition.expeditionId()
        ).orElseThrow(() -> new EventStateConflictException(
                "Событие ещё не открыто",
                "NOT_STARTED"
        ));
        validateOpenEvent(current, command.eventId());
        ExpeditionEventChoiceDefinition choice = content.requireChoice(
                command.eventId(),
                command.choiceId()
        );

        ProgressionRewardResult reward = progressionService.rewardEvent(
                command.userId(),
                choice.pilotExperienceReward(),
                choice.petBondReward(),
                serverTime
        );
        ExpeditionProgressState completed = current.resolve(command.eventId());
        EventResolutionResult result = new EventResolutionResult(
                definition.contentVersion(),
                definition.expeditionId(),
                completed.status(),
                completed.version(),
                command.eventId(),
                definition.event().title(),
                EventResolutionStatus.RESOLVED,
                choice.choiceId(),
                choice.title(),
                choice.outcomeTitle(),
                choice.outcomeSummary(),
                new EventPilotRewardResult(
                        reward.pilotDefinition().pilotId(),
                        reward.pilotDefinition().name(),
                        reward.pilot().level(),
                        reward.pilotExperienceGained(),
                        reward.pilot().currentExperience(),
                        reward.pilot().nextLevelExperience(),
                        reward.pilot().version()
                ),
                new EventPetRewardResult(
                        reward.petDefinition().petId(),
                        reward.petDefinition().name(),
                        reward.pet().level(),
                        reward.petBondGained(),
                        reward.pet().bond(),
                        reward.pet().version()
                ),
                serverTime
        );

        expeditionRepository.saveState(
                command.userId(),
                definition.expeditionId(),
                completed,
                serverTime
        );
        eventRepository.saveProcessed(
                scope,
                new ProcessedEventResolution(fingerprint, result)
        );
        return result;
    }

    private void validateOpenEvent(ExpeditionProgressState state, String eventId) {
        if (state.status() != ExpeditionProgressStatus.EVENT_READY) {
            throw new EventStateConflictException(
                    state.status() == ExpeditionProgressStatus.COMPLETED
                            ? "Событие уже разрешено"
                            : "Событие ещё не готово к разрешению",
                    state.status().name()
            );
        }
        if (!eventId.equals(state.unlockedEventId())) {
            throw new EventStateConflictException(
                    "Запрошенное событие не открыто для пользователя",
                    state.status().name()
            );
        }
    }
}
