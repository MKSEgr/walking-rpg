package com.walkingrpg.backend.activity.retention;

@FunctionalInterface
public interface ActivityRetentionPolicy {

    int retentionDays();
}
