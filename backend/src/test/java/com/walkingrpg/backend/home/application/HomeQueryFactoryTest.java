package com.walkingrpg.backend.home.application;

import java.time.LocalDate;

import com.walkingrpg.backend.home.domain.HomeQuery;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class HomeQueryFactoryTest {

    private final HomeQueryFactory factory = new HomeQueryFactory();

    @Test
    void shouldNormalizeUserAndParseIsoDate() {
        HomeQuery query = factory.create("  user-1  ", "2026-07-25");

        assertEquals("user-1", query.userId());
        assertEquals(LocalDate.of(2026, 7, 25), query.localDate());
    }

    @Test
    void shouldRejectInvalidLocalDate() {
        HomeQueryValidationException exception = assertThrows(
                HomeQueryValidationException.class,
                () -> factory.create("user-1", "25.07.2026")
        );

        assertEquals("localDate", exception.field());
    }

    @Test
    void shouldRejectBlankUserHeader() {
        HomeQueryValidationException exception = assertThrows(
                HomeQueryValidationException.class,
                () -> factory.create(" ", "2026-07-25")
        );

        assertEquals("userId", exception.field());
    }
}
