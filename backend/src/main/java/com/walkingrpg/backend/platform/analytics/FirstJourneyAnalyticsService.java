package com.walkingrpg.backend.platform.analytics;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import com.walkingrpg.backend.platform.application.PlatformValidationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FirstJourneyAnalyticsService {

    private static final int MAXIMUM_COHORT_CODE_LENGTH = 64;

    private static final String COHORT_FILTER = """
            (
                CAST(? AS varchar) IS NULL
                OR EXISTS (
                    SELECT 1
                    FROM tester_cohort_member cohort
                    WHERE cohort.user_id = subject.user_id
                      AND cohort.cohort_code = CAST(? AS varchar)
                )
            )
            """;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    public FirstJourneyAnalyticsService(JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public FirstJourneyAnalyticsSnapshot summary(String cohortCode) {
        String normalizedCohort = normalizeCohort(cohortCode);
        long eligibleUsers = eligibleUsers(normalizedCohort);
        long startedUsers = startedUsers(normalizedCohort);
        List<FirstJourneyStageMetric> stages = FirstJourneyMilestone.measuredStages()
                .stream()
                .map(milestone -> stageMetric(
                        normalizedCohort,
                        startedUsers,
                        milestone
                ))
                .toList();
        FirstJourneyDataQuality dataQuality = dataQuality(normalizedCohort);
        return new FirstJourneyAnalyticsSnapshot(
                normalizedCohort,
                eligibleUsers,
                startedUsers,
                Math.max(0, eligibleUsers - startedUsers),
                ratio(startedUsers, eligibleUsers),
                stages,
                dataQuality,
                Instant.now(clock).truncatedTo(ChronoUnit.MICROS)
        );
    }

    private long eligibleUsers(String cohortCode) {
        Long result = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM app_user subject
                WHERE
                """ + COHORT_FILTER, Long.class, cohortCode, cohortCode);
        return value(result);
    }

    private long startedUsers(String cohortCode) {
        Long result = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM first_journey_milestone started
                JOIN app_user subject ON subject.user_id = started.user_id
                WHERE started.milestone = 'JOURNEY_STARTED'
                  AND
                """ + COHORT_FILTER, Long.class, cohortCode, cohortCode);
        return value(result);
    }

    private FirstJourneyStageMetric stageMetric(
            String cohortCode,
            long startedUsers,
            FirstJourneyMilestone milestone
    ) {
        StageRow row = jdbcTemplate.queryForObject("""
                WITH started AS (
                    SELECT start_marker.user_id,
                           start_marker.occurred_at,
                           start_marker.source
                    FROM first_journey_milestone start_marker
                    JOIN app_user subject ON subject.user_id = start_marker.user_id
                    WHERE start_marker.milestone = 'JOURNEY_STARTED'
                      AND
                """ + COHORT_FILTER + """
                )
                SELECT count(target.user_id) AS reached_users,
                       count(target.user_id) FILTER (
                           WHERE target.source = 'AUTHORITATIVE'
                       ) AS authoritative_reached_users,
                       count(target.user_id) FILTER (
                           WHERE started.source = 'AUTHORITATIVE'
                             AND target.source = 'AUTHORITATIVE'
                             AND target.occurred_at >= started.occurred_at
                       ) AS timed_users,
                       percentile_cont(0.5) WITHIN GROUP (
                           ORDER BY extract(
                               epoch FROM target.occurred_at - started.occurred_at
                           )
                       ) FILTER (
                           WHERE started.source = 'AUTHORITATIVE'
                             AND target.source = 'AUTHORITATIVE'
                             AND target.occurred_at >= started.occurred_at
                       ) AS median_seconds,
                       percentile_cont(0.9) WITHIN GROUP (
                           ORDER BY extract(
                               epoch FROM target.occurred_at - started.occurred_at
                           )
                       ) FILTER (
                           WHERE started.source = 'AUTHORITATIVE'
                             AND target.source = 'AUTHORITATIVE'
                             AND target.occurred_at >= started.occurred_at
                       ) AS p90_seconds
                FROM started
                LEFT JOIN first_journey_milestone target
                  ON target.user_id = started.user_id
                 AND target.milestone = ?
                """, (resultSet, rowNumber) -> new StageRow(
                resultSet.getLong("reached_users"),
                resultSet.getLong("authoritative_reached_users"),
                resultSet.getLong("timed_users"),
                nullableRoundedLong(resultSet.getObject("median_seconds")),
                nullableRoundedLong(resultSet.getObject("p90_seconds"))
        ), cohortCode, cohortCode, milestone.name());

        if (row == null) {
            throw new IllegalStateException("First journey analytics query returned no row");
        }
        return new FirstJourneyStageMetric(
                milestone,
                row.reachedUsers(),
                Math.max(0, startedUsers - row.reachedUsers()),
                row.authoritativeReachedUsers(),
                row.timedUsers(),
                ratio(row.reachedUsers(), startedUsers),
                row.medianSeconds(),
                row.p90Seconds()
        );
    }

    private FirstJourneyDataQuality dataQuality(String cohortCode) {
        FirstJourneyDataQuality result = jdbcTemplate.queryForObject("""
                SELECT count(*) FILTER (
                           WHERE milestone.source = 'AUTHORITATIVE'
                       ) AS authoritative_records,
                       count(*) FILTER (
                           WHERE milestone.source = 'BACKFILLED'
                       ) AS backfilled_records
                FROM first_journey_milestone milestone
                JOIN app_user subject ON subject.user_id = milestone.user_id
                WHERE EXISTS (
                    SELECT 1
                    FROM first_journey_milestone started
                    WHERE started.user_id = milestone.user_id
                      AND started.milestone = 'JOURNEY_STARTED'
                )
                  AND
                """ + COHORT_FILTER, (resultSet, rowNumber) ->
                new FirstJourneyDataQuality(
                        resultSet.getLong("authoritative_records"),
                        resultSet.getLong("backfilled_records")
                ), cohortCode, cohortCode);
        if (result == null) {
            throw new IllegalStateException("First journey data-quality query returned no row");
        }
        return result;
    }

    private String normalizeCohort(String cohortCode) {
        if (cohortCode == null) {
            return null;
        }
        String normalized = cohortCode.trim();
        if (normalized.isEmpty()) {
            return null;
        }
        if (normalized.length() > MAXIMUM_COHORT_CODE_LENGTH) {
            throw new PlatformValidationException(
                    "cohortCode не может быть длиннее 64 символов",
                    "cohortCode"
            );
        }
        return normalized;
    }

    private long value(Long number) {
        return number == null ? 0 : number;
    }

    private double ratio(long numerator, long denominator) {
        return denominator == 0 ? 0.0 : numerator * 1.0 / denominator;
    }

    private static Long nullableRoundedLong(Object value) {
        if (value == null) {
            return null;
        }
        if (!(value instanceof Number number)) {
            throw new IllegalStateException(
                    "Unexpected percentile value type: " + value.getClass().getName()
            );
        }
        return Math.round(number.doubleValue());
    }

    private record StageRow(
            long reachedUsers,
            long authoritativeReachedUsers,
            long timedUsers,
            Long medianSeconds,
            Long p90Seconds
    ) {
    }
}
