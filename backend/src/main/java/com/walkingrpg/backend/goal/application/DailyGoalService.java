package com.walkingrpg.backend.goal.application;

import java.time.LocalDate;
import java.util.List;
import java.util.Objects;
import java.util.Set;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.domain.WeeklyActivityDay;
import com.walkingrpg.backend.goal.domain.WeeklyActivityRhythm;
import com.walkingrpg.backend.goal.infrastructure.DailyGoalHistoryRepository;
import org.springframework.stereotype.Service;

@Service
public class DailyGoalService {

    private static final int WEEKLY_RHYTHM_WINDOW_DAYS = 7;
    private static final int WEEKLY_RHYTHM_TARGET_ACTIVE_DAYS = 4;

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

    public WeeklyActivityRhythm calculateWeeklyRhythm(
            String userId,
            LocalDate localDate
    ) {
        String normalizedUserId = requireText(userId, "userId");
        LocalDate targetDate = Objects.requireNonNull(localDate, "localDate");
        LocalDate fromInclusive = targetDate.minusDays(
                WEEKLY_RHYTHM_WINDOW_DAYS - 1L
        );
        List<LocalDate> acceptedDateList = repository.findAcceptedDates(
                normalizedUserId,
                fromInclusive,
                targetDate.plusDays(1)
        );
        Set<LocalDate> acceptedDates = Set.copyOf(acceptedDateList);
        if (acceptedDates.size() != acceptedDateList.size()) {
            throw new IllegalStateException(
                    "История активности содержит повторяющиеся даты"
            );
        }
        List<WeeklyActivityDay> days = fromInclusive
                .datesUntil(targetDate.plusDays(1))
                .map(date -> new WeeklyActivityDay(
                        date,
                        acceptedDates.contains(date)
                ))
                .toList();
        return new WeeklyActivityRhythm(
                acceptedDates.size(),
                WEEKLY_RHYTHM_WINDOW_DAYS,
                WEEKLY_RHYTHM_TARGET_ACTIVE_DAYS,
                days
        );
    }

    private String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return value.trim();
    }
}
