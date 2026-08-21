package com.walkingrpg.backend.goal.infrastructure;

import java.time.LocalDate;
import java.util.List;

public interface DailyGoalHistoryRepository {

    List<Long> findAcceptedTotals(
            String userId,
            LocalDate fromInclusive,
            LocalDate toExclusive
    );

    default List<LocalDate> findAcceptedDates(
            String userId,
            LocalDate fromInclusive,
            LocalDate toExclusive
    ) {
        if (!findAcceptedTotals(
                userId,
                fromInclusive,
                toExclusive
        ).isEmpty()) {
            throw new IllegalStateException(
                    "Репозиторий не поддерживает authoritative dates"
            );
        }
        return List.of();
    }
}
