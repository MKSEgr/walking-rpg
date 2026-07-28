package com.walkingrpg.backend.home.api;

import com.walkingrpg.backend.home.application.HomeQueryFactory;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.constraints.NotNull;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/home")
public class HomeController {

    private final HomeQueryFactory queryFactory;
    private final HomeService homeService;
    private final RequestIdentityProvider identityProvider;

    public HomeController(
            HomeQueryFactory queryFactory,
            HomeService homeService,
            RequestIdentityProvider identityProvider
    ) {
        this.queryFactory = queryFactory;
        this.homeService = homeService;
        this.identityProvider = identityProvider;
    }

    @GetMapping
    public HomeSnapshotResponse getHome(
            @RequestParam("localDate") @NotNull String localDate
    ) {
        return homeService.getSnapshot(queryFactory.create(
                identityProvider.requireIdentity().userId(),
                localDate
        ));
    }
}
