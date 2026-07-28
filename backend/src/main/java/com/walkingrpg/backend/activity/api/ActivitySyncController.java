package com.walkingrpg.backend.activity.api;

import com.walkingrpg.backend.activity.application.ActivitySyncCommandFactory;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.security.RequestIdentity;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/activity")
public class ActivitySyncController {

    private final ActivitySyncCommandFactory commandFactory;
    private final ActivitySyncService activitySyncService;
    private final RequestIdentityProvider identityProvider;

    public ActivitySyncController(
            ActivitySyncCommandFactory commandFactory,
            ActivitySyncService activitySyncService,
            RequestIdentityProvider identityProvider
    ) {
        this.commandFactory = commandFactory;
        this.activitySyncService = activitySyncService;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/sync")
    public ActivitySyncResponse sync(
            @Valid @RequestBody ActivitySyncRequest request
    ) {
        RequestIdentity identity = identityProvider.requireIdentity();
        ActivitySyncOutcome outcome = activitySyncService.synchronize(
                commandFactory.create(
                        identity.userId(),
                        identity.requireDeviceId(),
                        request
                )
        );
        ActivitySyncResult result = outcome.activity();

        return new ActivitySyncResponse(
                result.acceptedTotal(),
                result.acceptedDelta(),
                result.energyGranted(),
                outcome.energyBalanceAfter(),
                outcome.economyVersion(),
                result.riskStatus(),
                result.stateVersion(),
                result.serverTime()
        );
    }
}
