package com.walkingrpg.backend.platform.application;

import java.math.BigDecimal;
import java.math.BigInteger;

final class PlatformNumbers {

    private PlatformNumbers() {
    }

    static int requireInteger(Object value, String field) {
        try {
            return decimal(value).intValueExact();
        } catch (ArithmeticException | NumberFormatException exception) {
            throw invalidInteger(field);
        }
    }

    static long requireLongInteger(Object value, String field) {
        try {
            return decimal(value).longValueExact();
        } catch (ArithmeticException | NumberFormatException exception) {
            throw invalidInteger(field);
        }
    }

    static Integer integerOrNull(Object value) {
        try {
            return decimal(value).intValueExact();
        } catch (ArithmeticException | NumberFormatException exception) {
            return null;
        }
    }

    private static BigDecimal decimal(Object value) {
        if (!(value instanceof Number number)) {
            throw new NumberFormatException("Not a number");
        }
        if (number instanceof BigDecimal decimal) {
            return decimal;
        }
        if (number instanceof BigInteger integer) {
            return new BigDecimal(integer);
        }
        if (number instanceof Byte
                || number instanceof Short
                || number instanceof Integer
                || number instanceof Long) {
            return BigDecimal.valueOf(number.longValue());
        }
        if (number instanceof Float || number instanceof Double) {
            double floatingPoint = number.doubleValue();
            if (!Double.isFinite(floatingPoint)) {
                throw new NumberFormatException("Non-finite number");
            }
            return BigDecimal.valueOf(floatingPoint);
        }
        return new BigDecimal(number.toString());
    }

    private static PlatformValidationException invalidInteger(String field) {
        return new PlatformValidationException(
                "Поле должно быть целым числом без дробной части",
                field
        );
    }
}
