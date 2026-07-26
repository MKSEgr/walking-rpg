package com.walkingrpg.backend.goal.application;

import java.time.LocalDate;
import java.util.List;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.infrastructure.DailyGoalHistoryRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class DailyGoalServiceTest {

    @Test
    void shouldReadOnlyTheConfiguredWindowBeforeTargetDate() {
        LocalDate targetDate = LocalDate.of(2026, 7, 26);
        CapturingRepository repository = new CapturingRepository(
                List.of(2_000L, 3_000L, 4_000L)
        );
        DailyGoalPolicyProperties properties =
                AdaptiveDailyGoalCalculatorTest.properties();
        DailyGoalService service = new DailyGoalService(
                repository,
                new AdaptiveDailyGoalCalculator(properties),
                properties
        );

        DailyGoal goal = service.calculate("user-1", targetDate);

        assertEquals("user-1", repository.userId);
        assertEquals(targetDate.minusDays(7), repository.fromInclusive);
        assertEquals(targetDate, repository.toExclusive);
        assertEquals(3_250, goal.steps());
    }

    private static final class CapturingRepository
            implements DailyGoalHistoryRepository {

        private final List<Long> totals;
        private String userId;
        private LocalDate fromInclusive;
        private LocalDate toExclusive;

        private CapturingRepository(List<Long> totals) {
            this.totals = totals;
        }

        @Override
        public List<Long> findAcceptedTotals(
                String userId,
                LocalDate fromInclusive,
                LocalDate toExclusive
        ) {
            this.userId = userId;
            this.fromInclusive = fromInclusive;
            this.toExclusive = toExclusive;
            return totals;
        }
    }
}
