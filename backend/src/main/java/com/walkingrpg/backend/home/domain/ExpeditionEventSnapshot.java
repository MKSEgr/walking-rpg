package com.walkingrpg.backend.home.domain;

public record ExpeditionEventSnapshot(
        String eventId,
        String title,
        String summary,
        String status
) {
}
