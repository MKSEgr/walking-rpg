package com.walkingrpg.backend.goal.application;

import java.time.LocalDate;
import java.util.List;
import java.util.Objects;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.infrastructure.DailyGoalHistoryRepository;
import org.springframework.stereotype.Service;

@Service
public class DailyGoalService {

    private final DailyGoalHistoryRepository repository;
    private final AdaptiveDailyGoalCalculator calculator;
    private final DailyGoalPolicyProperties properties;

    public DailyGoalService(
            DailyGoalHistoryRepository repository,
            AdaptiveDailyGoalCalculator calculator,
            DailyGoalPolicyProperties properties
    ) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.calculator = Objects.requireNonNull(calculator, "calculator");
        this.properties = Objects.requireNonNull(properties, "properties");
    }

    public DailyGoal calculate(String userId, LocalDate localDate) {
        String normalizedUserId = requireText(userId, "userId");
        LocalDate targetDate = Objects.requireNonNull(localDate, "localDate");
        LocalDate fromInclusive = targetDate.minusDays(properties.lookbackDays());
        List<Long> acceptedTotals = repository.findAcceptedTotals(
                normalizedUserId,
                fromInclusive,
                targetDate
        );
        return calculator.calculate(acceptedTotals);
    }

    private String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return value.trim();
    }
}
