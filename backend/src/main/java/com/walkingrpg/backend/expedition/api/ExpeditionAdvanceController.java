package com.walkingrpg.backend.expedition.api;

import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceCommandFactory;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventStatus;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/expeditions")
public class ExpeditionAdvanceController {

    static final String USER_HEADER = "X-User-Id";

    private final ExpeditionAdvanceCommandFactory commandFactory;
    private final ExpeditionAdvanceService service;

    public ExpeditionAdvanceController(
            ExpeditionAdvanceCommandFactory commandFactory,
            ExpeditionAdvanceService service
    ) {
        this.commandFactory = commandFactory;
        this.service = service;
    }

    @PostMapping("/{expeditionId}/advance")
    public ExpeditionAdvanceResponse advance(
            @RequestHeader(USER_HEADER) String userId,
            @PathVariable String expeditionId,
            @Valid @RequestBody ExpeditionAdvanceRequest request
    ) {
        ExpeditionAdvanceResult result = service.advance(
                commandFactory.create(userId, expeditionId, request)
        );

        return new ExpeditionAdvanceResponse(
                result.contentVersion(),
                result.expeditionId(),
                result.expeditionName(),
                result.energySpent(),
                result.energyBalanceAfter(),
                result.economyVersion(),
                result.progressAfter(),
                result.requiredEnergy(),
                result.expeditionVersion(),
                result.status(),
                result.currentNodeId(),
                result.currentNodeName(),
                result.unlockedEvent() == null
                        ? null
                        : new ExpeditionEventResponse(
                                result.unlockedEvent().eventId(),
                                result.unlockedEvent().title(),
                                result.unlockedEvent().summary(),
                                ExpeditionEventStatus.READY
                        ),
                result.serverTime()
        );
    }
}
