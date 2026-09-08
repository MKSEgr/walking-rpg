package com.walkingrpg.backend.platform.infrastructure;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.Map;

import com.walkingrpg.backend.activity.retention.ActivityRetentionPolicy;
import org.springframework.stereotype.Component;

@Component
public class PlatformActivityRetentionPolicy implements ActivityRetentionPolicy {

    private static final int DEFAULT_RETENTION_DAYS = 30;
    private static final int MIN_RETENTION_DAYS = 1;
    private static final int MAX_RETENTION_DAYS = 3650;

    private final PlatformRepository repository;

    public PlatformActivityRetentionPolicy(PlatformRepository repository) {
        this.repository = repository;
    }

    @Override
    public int retentionDays() {
        Map<String, Object> config = repository.activeRemoteConfig();
        Integer configuredDays = config == null
                ? null
                : integerOrNull(config.get("activityRetentionDays"));
        if (configuredDays == null
                || configuredDays < MIN_RETENTION_DAYS
                || configuredDays > MAX_RETENTION_DAYS) {
            return DEFAULT_RETENTION_DAYS;
        }
        return configuredDays;
    }

    private Integer integerOrNull(Object value) {
        if (!(value instanceof Number number)) {
            return null;
        }
        try {
            if (number instanceof BigDecimal decimal) {
                return decimal.intValueExact();
            }
            if (number instanceof BigInteger integer) {
                return integer.intValueExact();
            }
            if (number instanceof Byte
                    || number instanceof Short
                    || number instanceof Integer
                    || number instanceof Long) {
                return Math.toIntExact(number.longValue());
            }
            if (number instanceof Float || number instanceof Double) {
                double floatingPoint = number.doubleValue();
                if (!Double.isFinite(floatingPoint)) {
                    return null;
                }
                return BigDecimal.valueOf(floatingPoint).intValueExact();
            }
            return new BigDecimal(number.toString()).intValueExact();
        } catch (ArithmeticException | NumberFormatException exception) {
            return null;
        }
    }
}
