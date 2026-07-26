package com.walkingrpg.backend.goal.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.domain.DailyGoalSource;
import org.springframework.stereotype.Component;

@Component
public class AdaptiveDailyGoalCalculator {

    private static final BigDecimal ONE_HUNDRED = BigDecimal.valueOf(100);
    private static final BigDecimal TWO = BigDecimal.valueOf(2);

    private final DailyGoalPolicyProperties properties;

    public AdaptiveDailyGoalCalculator(DailyGoalPolicyProperties properties) {
        this.properties = Objects.requireNonNull(properties, "properties");
    }

    public DailyGoal calculate(List<Long> acceptedTotals) {
        Objects.requireNonNull(acceptedTotals, "acceptedTotals");
        List<Long> validTotals = normalize(acceptedTotals);

        if (validTotals.size() < properties.minimumSampleDays()) {
            return result(
                    properties.defaultGoal(),
                    DailyGoalSource.DEFAULT,
                    null,
                    validTotals.size()
            );
        }

        BigDecimal median = median(validTotals);
        BigDecimal grown = median.multiply(
                BigDecimal.valueOf(100L + properties.growthPercent())
        ).divide(ONE_HUNDRED);
        long goal = roundAndClamp(grown);
        return result(
                goal,
                DailyGoalSource.ADAPTIVE,
                median,
                validTotals.size()
        );
    }

    private List<Long> normalize(List<Long> acceptedTotals) {
        List<Long> validTotals = new ArrayList<>(acceptedTotals.size());
        for (Long acceptedTotal : acceptedTotals) {
            if (acceptedTotal == null) {
                throw new IllegalArgumentException("acceptedTotal не может быть null");
            }
            if (acceptedTotal < 0) {
                throw new IllegalArgumentException("acceptedTotal не может быть отрицательным");
            }
            if (acceptedTotal > 0) {
                validTotals.add(acceptedTotal);
            }
        }
        validTotals.sort(Comparator.naturalOrder());
        return List.copyOf(validTotals);
    }

    private BigDecimal median(List<Long> sortedTotals) {
        int size = sortedTotals.size();
        int middle = size / 2;
        if ((size & 1) == 1) {
            return BigDecimal.valueOf(sortedTotals.get(middle));
        }
        return BigDecimal.valueOf(sortedTotals.get(middle - 1))
                .add(BigDecimal.valueOf(sortedTotals.get(middle)))
                .divide(TWO);
    }

    private long roundAndClamp(BigDecimal value) {
        BigDecimal step = BigDecimal.valueOf(properties.roundingStep());
        BigDecimal rounded = value.divide(step, 0, RoundingMode.HALF_UP)
                .multiply(step);
        BigDecimal clamped = rounded
                .max(BigDecimal.valueOf(properties.minimumGoal()))
                .min(BigDecimal.valueOf(properties.maximumGoal()));
        return clamped.longValueExact();
    }

    private DailyGoal result(
            long steps,
            DailyGoalSource source,
            BigDecimal baselineSteps,
            int sampleDays
    ) {
        return new DailyGoal(
                steps,
                source,
                baselineSteps,
                sampleDays,
                properties.lookbackDays(),
                properties.minimumSampleDays(),
                properties.defaultGoal(),
                properties.growthPercent(),
                properties.roundingStep(),
                properties.minimumGoal(),
                properties.maximumGoal(),
                properties.policyVersion()
        );
    }
}
