package com.walkingrpg.backend.system.api;

import java.time.Clock;
import java.time.Instant;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/system")
public class SystemInfoController {

    private final Clock clock;

    public SystemInfoController(Clock clock) {
        this.clock = clock;
    }

    @GetMapping("/info")
    public SystemInfoResponse info() {
        return new SystemInfoResponse(
                "walking-rpg-backend",
                "0.1.0-SNAPSHOT",
                "UP",
                Instant.now(clock)
        );
    }
}
