package com.walkingrpg.backend.activity.domain;

import java.time.LocalDate;

public record ActivityDayKey(
        String userId,
        LocalDate localDate
) {
    public static ActivityDayKey from(ActivitySyncCommand command) {
        return new ActivityDayKey(
                command.userId(),
                command.localDate()
        );
    }
}
