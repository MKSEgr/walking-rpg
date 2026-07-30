package com.walkingrpg.backend.expedition.application;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("walking-rpg.event-result-handoff")
public record EventResultHandoffProperties(boolean enabled) {
}
