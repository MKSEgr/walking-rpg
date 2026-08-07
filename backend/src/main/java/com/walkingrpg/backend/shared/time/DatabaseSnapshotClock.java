package com.walkingrpg.backend.shared.time;

import java.time.Instant;

@FunctionalInterface
public interface DatabaseSnapshotClock {

    Instant observe();
}
