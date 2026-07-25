package com.walkingrpg.backend.home.api;

import com.walkingrpg.backend.home.application.HomeQueryFactory;
import com.walkingrpg.backend.home.application.HomeService;
import jakarta.validation.constraints.NotNull;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/home")
public class HomeController {

    static final String USER_HEADER = "X-User-Id";

    private final HomeQueryFactory queryFactory;
    private final HomeService homeService;

    public HomeController(
            HomeQueryFactory queryFactory,
            HomeService homeService
    ) {
        this.queryFactory = queryFactory;
        this.homeService = homeService;
    }

    @GetMapping
    public HomeSnapshotResponse getHome(
            @RequestHeader(USER_HEADER) String userId,
            @RequestParam("localDate") @NotNull String localDate
    ) {
        return homeService.getSnapshot(queryFactory.create(userId, localDate));
    }
}
