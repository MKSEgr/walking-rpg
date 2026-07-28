package com.walkingrpg.backend.home.application;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import com.walkingrpg.backend.home.domain.HomeQuery;
import org.springframework.stereotype.Component;

@Component
public class HomeQueryFactory {

    public HomeQuery create(String userId, String localDate) {
        return new HomeQuery(
                requireText(userId, "userId", 128),
                parseLocalDate(localDate)
        );
    }

    private LocalDate parseLocalDate(String value) {
        String normalized = requireText(value, "localDate", 10);
        try {
            return LocalDate.parse(normalized);
        } catch (DateTimeParseException exception) {
            throw new HomeQueryValidationException(
                    "localDate",
                    "Дата должна быть указана в формате YYYY-MM-DD"
            );
        }
    }

    private String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new HomeQueryValidationException(field, "Значение обязательно");
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new HomeQueryValidationException(
                    field,
                    "Максимальная длина — " + maxLength + " символов"
            );
        }
        return normalized;
    }
}
