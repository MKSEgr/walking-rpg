package com.walkingrpg.backend.expedition.api;

import com.walkingrpg.backend.expedition.application.ExpeditionJourneyCommandFactory;
import com.walkingrpg.backend.expedition.application.ExpeditionJourneyService;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyStartResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/expeditions")
public class ExpeditionJourneyController {

    private final ExpeditionJourneyCommandFactory commandFactory;
    private final ExpeditionJourneyService service;
    private final RequestIdentityProvider identityProvider;

    public ExpeditionJourneyController(
            ExpeditionJourneyCommandFactory commandFactory,
            ExpeditionJourneyService service,
            RequestIdentityProvider identityProvider
    ) {
        this.commandFactory = commandFactory;
        this.service = service;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/{expeditionId}/journeys")
    public ExpeditionJourneyResponse beginNextJourney(
            @PathVariable String expeditionId,
            @Valid @RequestBody ExpeditionJourneyRequest request
    ) {
        ExpeditionJourneyStartResult result = service.beginNextJourney(
                commandFactory.create(
                        identityProvider.requireIdentity().userId(),
                        expeditionId,
                        request
                )
        );
        return new ExpeditionJourneyResponse(
                result.contentVersion(),
                result.expeditionId(),
                result.expeditionName(),
                result.journeyNumber(),
                result.progressAfter(),
                result.requiredEnergy(),
                result.expeditionVersion(),
                result.status(),
                result.currentNodeId(),
                result.currentNodeName(),
                result.serverTime()
        );
    }
}
