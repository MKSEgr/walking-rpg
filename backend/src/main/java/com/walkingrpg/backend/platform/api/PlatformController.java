package com.walkingrpg.backend.platform.api;

import java.util.Map;

import com.walkingrpg.backend.platform.application.PlatformService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PlatformController {

    public static final String USER_HEADER = "X-User-Id";

    private final PlatformService platformService;

    public PlatformController(PlatformService platformService) {
        this.platformService = platformService;
    }

    @GetMapping("/platform")
    public PlatformSnapshotResponse platform(
            @RequestHeader(USER_HEADER) String userId
    ) {
        return platformService.getSnapshot(userId);
    }

    @PostMapping("/platform/commands")
    public PlatformCommandResponse execute(
            @RequestHeader(USER_HEADER) String userId,
            @Valid @RequestBody PlatformCommandRequest request
    ) {
        return platformService.execute(userId, request);
    }

    @GetMapping("/content/bootstrap")
    public Map<String, Object> contentBootstrap() {
        return platformService.getContentBootstrap();
    }
}
