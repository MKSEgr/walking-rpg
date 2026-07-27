package com.walkingrpg.backend.activity.retention;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("walking-rpg.activity-retention")
public record ActivityRetentionProperties(int days) {
    public ActivityRetentionProperties {
        if (days <= 0) {
            days = 30;
        }
    }
}
