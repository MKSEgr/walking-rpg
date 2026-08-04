package com.walkingrpg.backend.expedition.api;

import java.util.UUID;

import com.walkingrpg.backend.expedition.application.EventResolutionValidationException;
import com.walkingrpg.backend.expedition.application.EventResultAcknowledgementService;
import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import com.walkingrpg.backend.shared.validation.CanonicalUuid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/event-results")
public class EventResultAcknowledgementController {

    private final EventResultAcknowledgementService service;
    private final RequestIdentityProvider identityProvider;

    public EventResultAcknowledgementController(
            EventResultAcknowledgementService service,
            RequestIdentityProvider identityProvider
    ) {
        this.service = service;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/{receiptId}/acknowledge")
    public EventResultAcknowledgementResponse acknowledge(
            @PathVariable String receiptId
    ) {
        EventResultAcknowledgementResult result = service.acknowledge(
                identityProvider.requireIdentity().userId(),
                parseReceiptId(receiptId)
        );
        return new EventResultAcknowledgementResponse(
                result.receiptId(),
                result.eventId(),
                "ACKNOWLEDGED",
                result.acknowledgedAt(),
                result.serverTime()
        );
    }

    private UUID parseReceiptId(String value) {
        try {
            return CanonicalUuid.parse(value);
        } catch (IllegalArgumentException exception) {
            throw new EventResolutionValidationException(
                    "receiptId должен быть полным UUID",
                    "receiptId"
            );
        }
    }
}
