package com.walkingrpg.backend.activity.retention;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivityRetentionService {

    private final ActivityRetentionRepository repository;
    private final ActivityRetentionPolicy policy;
    private final Clock clock;

    public ActivityRetentionService(
            ActivityRetentionRepository repository,
            ActivityRetentionPolicy policy,
            Clock clock
    ) {
        this.repository = repository;
        this.policy = policy;
        this.clock = clock;
    }

    @Transactional
    @Scheduled(cron = "${walking-rpg.activity-retention.cron:0 20 3 * * *}")
    public int cleanup() {
        Instant cutoff = Instant.now(clock)
                .minus(policy.retentionDays(), ChronoUnit.DAYS);
        return repository.deleteProcessedBefore(cutoff);
    }
}
