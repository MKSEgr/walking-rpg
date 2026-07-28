package com.walkingrpg.backend.platform.api;

import java.util.Map;

import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PlatformController {

    private final PlatformService platformService;
    private final RequestIdentityProvider identityProvider;

    public PlatformController(
            PlatformService platformService,
            RequestIdentityProvider identityProvider
    ) {
        this.platformService = platformService;
        this.identityProvider = identityProvider;
    }

    @GetMapping("/platform")
    public PlatformSnapshotResponse platform() {
        return platformService.getSnapshot(identityProvider.requireIdentity().userId());
    }

    @PostMapping("/platform/commands")
    public PlatformCommandResponse execute(
            @Valid @RequestBody PlatformCommandRequest request
    ) {
        return platformService.execute(
                identityProvider.requireIdentity().userId(),
                request
        );
    }

    @GetMapping("/content/bootstrap")
    public Map<String, Object> contentBootstrap() {
        return platformService.getContentBootstrap();
    }
}
