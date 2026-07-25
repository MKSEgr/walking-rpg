package com.walkingrpg.backend.activity.api;

import com.walkingrpg.backend.activity.application.ActivitySyncCommandFactory;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/activity")
public class ActivitySyncController {

    static final String USER_HEADER = "X-User-Id";
    static final String DEVICE_HEADER = "X-Device-Id";

    private final ActivitySyncCommandFactory commandFactory;
    private final ActivitySyncService activitySyncService;

    public ActivitySyncController(
            ActivitySyncCommandFactory commandFactory,
            ActivitySyncService activitySyncService
    ) {
        this.commandFactory = commandFactory;
        this.activitySyncService = activitySyncService;
    }

    @PostMapping("/sync")
    public ActivitySyncResponse sync(
            @RequestHeader(USER_HEADER) String userId,
            @RequestHeader(DEVICE_HEADER) String deviceId,
            @Valid @RequestBody ActivitySyncRequest request
    ) {
        ActivitySyncOutcome outcome = activitySyncService.synchronize(
                commandFactory.create(userId, deviceId, request)
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
