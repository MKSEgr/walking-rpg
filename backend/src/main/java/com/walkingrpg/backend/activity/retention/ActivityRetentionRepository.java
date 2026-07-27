package com.walkingrpg.backend.activity.retention;

import java.time.Instant;

public interface ActivityRetentionRepository {

    int deleteProcessedBefore(Instant cutoff);
}
