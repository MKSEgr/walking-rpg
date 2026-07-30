package com.walkingrpg.backend.expedition.api;

import com.walkingrpg.backend.expedition.application.EventResolutionCommandFactory;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.EventResultHandoffProperties;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/events")
public class EventResolutionController {

    static final String CLIENT_CAPABILITIES_HEADER =
            "X-Walking-RPG-Capabilities";
    static final String DURABLE_HANDOFF_CAPABILITY =
            "durable-event-result-v1";

    private final EventResolutionCommandFactory commandFactory;
    private final EventResolutionService service;
    private final EventResultHandoffProperties handoffProperties;
    private final RequestIdentityProvider identityProvider;

    public EventResolutionController(
            EventResolutionCommandFactory commandFactory,
            EventResolutionService service,
            EventResultHandoffProperties handoffProperties,
            RequestIdentityProvider identityProvider
    ) {
        this.commandFactory = commandFactory;
        this.service = service;
        this.handoffProperties = handoffProperties;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/{eventId}/resolve")
    public EventResolutionResponse resolve(
            @PathVariable String eventId,
            @RequestHeader(
                    name = CLIENT_CAPABILITIES_HEADER,
                    required = false
            ) String clientCapabilities,
            @Valid @RequestBody EventResolutionRequest request
    ) {
        EventResolutionResult result = service.resolve(
                commandFactory.create(
                        identityProvider.requireIdentity().userId(),
                        eventId,
                        request
                ),
                handoffProperties.enabled()
                        && supportsDurableHandoff(clientCapabilities)
        );
        return new EventResolutionResponse(
                result.receiptId(),
                result.contentVersion(),
                result.expeditionId(),
                result.expeditionStatus(),
                result.expeditionVersion(),
                result.eventId(),
                result.eventTitle(),
                result.status(),
                result.choiceId(),
                result.choiceTitle(),
                result.outcomeTitle(),
                result.outcomeSummary(),
                new EventPilotRewardResponse(
                        result.pilot().pilotId(),
                        result.pilot().name(),
                        result.pilot().level(),
                        result.pilot().experienceGained(),
                        result.pilot().currentExperience(),
                        result.pilot().nextLevelExperience(),
                        result.pilot().version()
                ),
                new EventPetRewardResponse(
                        result.pet().petId(),
                        result.pet().name(),
                        result.pet().level(),
                        result.pet().bondGained(),
                        result.pet().bond(),
                        result.pet().version()
                ),
                result.material() == null
                        ? null
                        : new EventMaterialRewardResponse(
                                result.material().itemId(),
                                result.material().name(),
                                result.material().description(),
                                result.material().quantityGained(),
                                result.material().quantityAfter(),
                                result.material().version()
                        ),
                result.handoffRequired(),
                result.nextNode() == null
                        ? null
                        : new EventNextNodeResponse(
                                result.nextNode().nodeId(),
                                result.nextNode().name()
                        ),
                result.serverTime()
        );
    }

    private boolean supportsDurableHandoff(String capabilities) {
        if (capabilities == null || capabilities.isBlank()) {
            return false;
        }
        for (String capability : capabilities.split(",")) {
            if (DURABLE_HANDOFF_CAPABILITY.equalsIgnoreCase(
                    capability.trim()
            )) {
                return true;
            }
        }
        return false;
    }
}
