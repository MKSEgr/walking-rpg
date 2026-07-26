package com.walkingrpg.backend.goal.infrastructure;

import java.time.LocalDate;
import java.util.List;

public interface DailyGoalHistoryRepository {

    List<Long> findAcceptedTotals(
            String userId,
            LocalDate fromInclusive,
            LocalDate toExclusive
    );
}
