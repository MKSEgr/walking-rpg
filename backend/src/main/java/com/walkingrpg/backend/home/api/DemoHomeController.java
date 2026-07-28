package com.walkingrpg.backend.home.api;

import com.walkingrpg.backend.home.application.DemoHomeService;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@ConditionalOnProperty(
        prefix = "walking-rpg.security",
        name = "demo-endpoints-enabled",
        havingValue = "true",
        matchIfMissing = false
)
@RequestMapping("/api/v1/home")
public class DemoHomeController {

    private final DemoHomeService demoHomeService;

    public DemoHomeController(DemoHomeService demoHomeService) {
        this.demoHomeService = demoHomeService;
    }

    @GetMapping("/demo")
    public HomeSnapshotResponse demo() {
        return demoHomeService.getDemoSnapshot();
    }
}
