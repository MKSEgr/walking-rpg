package com.walkingrpg.backend.goal.application;

import java.math.BigDecimal;
import java.util.List;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.domain.DailyGoalSource;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdaptiveDailyGoalCalculatorTest {

    private final DailyGoalPolicyProperties properties = properties();
    private final AdaptiveDailyGoalCalculator calculator =
            new AdaptiveDailyGoalCalculator(properties);

    @Test
    void shouldUseDefaultUntilMinimumHistoryIsCollected() {
        DailyGoal goal = calculator.calculate(List.of(2_000L, 4_000L));

        assertEquals(6_000, goal.steps());
        assertEquals(DailyGoalSource.DEFAULT, goal.source());
        assertNull(goal.baselineSteps());
        assertEquals(2, goal.sampleDays());
        assertEquals(6_000, goal.defaultGoal());
    }

    @Test
    void shouldCalculateMedianGrowthAndRoundingIndependentlyOfOrder() {
        DailyGoal goal = calculator.calculate(List.of(4_000L, 2_000L, 3_000L));

        assertEquals(BigDecimal.valueOf(3_000), goal.baselineSteps());
        assertEquals(3_250, goal.steps());
        assertEquals(DailyGoalSource.ADAPTIVE, goal.source());
        assertEquals(3, goal.sampleDays());
    }

    @Test
    void shouldUseExactEvenMedianBeforeGrowth() {
        DailyGoal goal = calculator.calculate(List.of(2_000L, 2_500L, 3_000L, 4_000L));

        assertEquals(BigDecimal.valueOf(2_750), goal.baselineSteps());
        assertEquals(3_000, goal.steps());
    }


    @Test
    void shouldPreserveHalfStepMedianInPolicyMetadata() {
        DailyGoal goal = calculator.calculate(List.of(2_000L, 2_501L, 3_000L, 4_000L));

        assertEquals(new BigDecimal("2750.5"), goal.baselineSteps());
        assertEquals(3_000, goal.steps());
    }

    @Test
    void shouldIgnoreZeroDaysAndClampToMinimum() {
        DailyGoal goal = calculator.calculate(List.of(0L, 500L, 1_000L, 1_500L));

        assertEquals(BigDecimal.valueOf(1_000), goal.baselineSteps());
        assertEquals(2_000, goal.steps());
        assertEquals(3, goal.sampleDays());
    }

    @Test
    void shouldClampToMaximum() {
        DailyGoal goal = calculator.calculate(List.of(18_000L, 20_000L, 22_000L));

        assertEquals(BigDecimal.valueOf(20_000), goal.baselineSteps());
        assertEquals(12_000, goal.steps());
    }

    @Test
    void shouldClampExtremeLongTotalsWithoutOverflow() {
        DailyGoal goal = calculator.calculate(List.of(
                Long.MAX_VALUE,
                Long.MAX_VALUE,
                Long.MAX_VALUE
        ));

        assertEquals(BigDecimal.valueOf(Long.MAX_VALUE), goal.baselineSteps());
        assertEquals(12_000, goal.steps());
    }

    @Test
    void shouldRejectNegativeHistory() {
        assertThrows(
                IllegalArgumentException.class,
                () -> calculator.calculate(List.of(2_000L, -1L, 3_000L))
        );
    }

    static DailyGoalPolicyProperties properties() {
        return new DailyGoalPolicyProperties(
                "adaptive-median-v1",
                7,
                3,
                6_000,
                2_000,
                12_000,
                5,
                250
        );
    }
}
