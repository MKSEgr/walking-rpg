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
    private final ActivityRetentionProperties properties;
    private final Clock clock;

    public ActivityRetentionService(
            ActivityRetentionRepository repository,
            ActivityRetentionProperties properties,
            Clock clock
    ) {
        this.repository = repository;
        this.properties = properties;
        this.clock = clock;
    }

    @Transactional
    @Scheduled(cron = "${walking-rpg.activity-retention.cron:0 20 3 * * *}")
    public int cleanup() {
        Instant cutoff = Instant.now(clock)
                .minus(properties.days(), ChronoUnit.DAYS);
        return repository.deleteProcessedBefore(cutoff);
    }
}
