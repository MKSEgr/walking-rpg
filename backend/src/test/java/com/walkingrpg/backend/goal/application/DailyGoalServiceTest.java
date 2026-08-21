package com.walkingrpg.backend.goal.application;

import java.time.LocalDate;
import java.util.List;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.domain.WeeklyActivityRhythm;
import com.walkingrpg.backend.goal.infrastructure.DailyGoalHistoryRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DailyGoalServiceTest {

    @Test
    void shouldReadOnlyTheConfiguredWindowBeforeTargetDate() {
        LocalDate targetDate = LocalDate.of(2026, 7, 26);
        CapturingRepository repository = new CapturingRepository(
                List.of(2_000L, 3_000L, 4_000L),
                List.of()
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

    @Test
    void shouldCountTheTargetDateAndSixPreviousActiveDays() {
        LocalDate targetDate = LocalDate.of(2026, 7, 26);
        CapturingRepository repository = new CapturingRepository(
                List.of(2_000L, 3_000L, 4_000L, 5_000L),
                List.of(
                        targetDate.minusDays(5),
                        targetDate.minusDays(3),
                        targetDate.minusDays(1),
                        targetDate
                )
        );
        DailyGoalPolicyProperties properties =
                AdaptiveDailyGoalCalculatorTest.properties();
        DailyGoalService service = new DailyGoalService(
                repository,
                new AdaptiveDailyGoalCalculator(properties),
                properties
        );

        WeeklyActivityRhythm rhythm = service.calculateWeeklyRhythm(
                " user-1 ",
                targetDate
        );

        assertEquals("user-1", repository.userId);
        assertEquals(targetDate.minusDays(6), repository.fromInclusive);
        assertEquals(targetDate.plusDays(1), repository.toExclusive);
        assertEquals(4, rhythm.activeDays());
        assertEquals(7, rhythm.windowDays());
        assertEquals(4, rhythm.targetActiveDays());
        assertEquals(true, rhythm.targetReached());
        assertEquals(7, rhythm.days().size());
        assertEquals(targetDate.minusDays(6),
                rhythm.days().getFirst().localDate());
        assertEquals(false, rhythm.days().getFirst().active());
        assertEquals(targetDate, rhythm.days().getLast().localDate());
        assertEquals(true, rhythm.days().getLast().active());
    }

    @Test
    void shouldRejectDuplicateAuthoritativeDates() {
        LocalDate targetDate = LocalDate.of(2026, 7, 26);
        CapturingRepository repository = new CapturingRepository(
                List.of(),
                List.of(targetDate, targetDate)
        );
        DailyGoalPolicyProperties properties =
                AdaptiveDailyGoalCalculatorTest.properties();
        DailyGoalService service = new DailyGoalService(
                repository,
                new AdaptiveDailyGoalCalculator(properties),
                properties
        );

        assertThrows(
                IllegalStateException.class,
                () -> service.calculateWeeklyRhythm("user-1", targetDate)
        );
    }

    @Test
    void shouldFailClosedWhenRepositoryCannotProvideActiveDates() {
        LocalDate targetDate = LocalDate.of(2026, 7, 26);
        DailyGoalHistoryRepository repository =
                (userId, fromInclusive, toExclusive) -> List.of(2_000L);
        DailyGoalPolicyProperties properties =
                AdaptiveDailyGoalCalculatorTest.properties();
        DailyGoalService service = new DailyGoalService(
                repository,
                new AdaptiveDailyGoalCalculator(properties),
                properties
        );

        assertThrows(
                IllegalStateException.class,
                () -> service.calculateWeeklyRhythm("user-1", targetDate)
        );
    }

    private static final class CapturingRepository
            implements DailyGoalHistoryRepository {

        private final List<Long> totals;
        private final List<LocalDate> dates;
        private String userId;
        private LocalDate fromInclusive;
        private LocalDate toExclusive;

        private CapturingRepository(
                List<Long> totals,
                List<LocalDate> dates
        ) {
            this.totals = totals;
            this.dates = dates;
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

        @Override
        public List<LocalDate> findAcceptedDates(
                String userId,
                LocalDate fromInclusive,
                LocalDate toExclusive
        ) {
            this.userId = userId;
            this.fromInclusive = fromInclusive;
            this.toExclusive = toExclusive;
            return dates;
        }
    }
}
