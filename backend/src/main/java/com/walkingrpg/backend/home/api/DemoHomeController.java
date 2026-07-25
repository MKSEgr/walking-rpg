package com.walkingrpg.backend.home.api;

import com.walkingrpg.backend.home.application.DemoHomeService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
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
