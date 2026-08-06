package com.walkingrpg.backend.platform.analytics;

import java.time.Instant;
import java.util.List;

import com.walkingrpg.backend.crafting.application.StarterCraftingContent;
import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.platform.application.PlatformValidationException;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CompassJourneyAnalyticsService {

    private static final int MAXIMUM_COHORT_CODE_LENGTH = 64;
    private static final String TELEMETRY_CONTRACT_VERSION =
            "compass-beta-funnel-v1";

    private static final String COHORT_FILTER = """
            (
                CAST(:cohortCode AS varchar) IS NULL
                OR EXISTS (
                    SELECT 1
                    FROM tester_cohort_member cohort
                    WHERE cohort.user_id = subject.user_id
                      AND cohort.cohort_code = CAST(:cohortCode AS varchar)
                )
            )
            """;

    private static final String STAGE_EVENTS = """
            /* compass journey stage events */
            WITH route_release AS (
                SELECT active_release.activated_at
                FROM content_release active_release
                WHERE active_release.content_version = :routeContentVersion
                  AND active_release.is_active
                  AND active_release.activated_at IS NOT NULL
                LIMIT 1
            ),
            compass_stage_event AS (
                SELECT event.user_id,
                       'RECIPE_SEEN' AS stage,
                       min(event.occurred_at) AS occurred_at,
                       'CLIENT_REPORTED' AS source
                FROM platform_event event
                WHERE event.event_name = 'compass_recipe_impression'
                  AND event.attributes ->> 'contractVersion' = :contractVersion
                  AND event.attributes ->> 'recipeId' = :recipeId
                GROUP BY event.user_id

                UNION ALL

                SELECT event.user_id,
                       'RECIPE_READY_SEEN',
                       min(event.occurred_at),
                       'CLIENT_REPORTED'
                FROM platform_event event
                WHERE event.event_name = 'compass_recipe_impression'
                  AND event.attributes ->> 'contractVersion' = :contractVersion
                  AND event.attributes ->> 'recipeId' = :recipeId
                  AND event.attributes ->> 'status' = 'READY'
                GROUP BY event.user_id

                UNION ALL

                SELECT item.user_id,
                       'COMPASS_CRAFTED',
                       min(item.crafted_at),
                       'AUTHORITATIVE'
                FROM unique_inventory_item item
                WHERE item.item_id = :compassItemId
                  AND item.recipe_id = :recipeId
                GROUP BY item.user_id

                UNION ALL

                SELECT command.user_id,
                       'COMPASS_EQUIPPED',
                       min(command.equipped_at),
                       'AUTHORITATIVE'
                FROM processed_equipment_command command
                WHERE command.slot_id = :navigationSlotId
                  AND command.action = 'EQUIP'
                  AND command.changed
                  AND command.item_id = :compassItemId
                GROUP BY command.user_id

                UNION ALL

                SELECT command.user_id,
                       'MIRROR_DELTA_REACHED',
                       greatest(
                           min(command.server_time),
                           release.activated_at
                       ),
                       'AUTHORITATIVE'
                FROM processed_expedition_advance command
                CROSS JOIN route_release release
                WHERE command.event_id = :mirrorEventId
                  AND NOT EXISTS (
                      SELECT 1
                      FROM processed_event_resolution resolution
                      WHERE resolution.user_id = command.user_id
                        AND resolution.expedition_id = command.expedition_id
                        AND resolution.event_id = :mirrorEventId
                        AND resolution.server_time < release.activated_at
                  )
                GROUP BY command.user_id, release.activated_at

                UNION ALL

                SELECT event.user_id,
                       'ROUTE_LOCKED_SEEN',
                       min(event.occurred_at),
                       'CLIENT_REPORTED'
                FROM platform_event event
                WHERE event.event_name = 'compass_route_impression'
                  AND event.attributes ->> 'contractVersion' = :contractVersion
                  AND event.attributes ->> 'eventId' = :mirrorEventId
                  AND event.attributes ->> 'choiceId' = :routeChoiceId
                  AND event.attributes ->> 'availability' = 'LOCKED'
                GROUP BY event.user_id

                UNION ALL

                SELECT event.user_id,
                       'ROUTE_AVAILABLE_SEEN',
                       min(event.occurred_at),
                       'CLIENT_REPORTED'
                FROM platform_event event
                WHERE event.event_name = 'compass_route_impression'
                  AND event.attributes ->> 'contractVersion' = :contractVersion
                  AND event.attributes ->> 'eventId' = :mirrorEventId
                  AND event.attributes ->> 'choiceId' = :routeChoiceId
                  AND event.attributes ->> 'availability' = 'AVAILABLE'
                GROUP BY event.user_id

                UNION ALL

                SELECT resolution.user_id,
                       'RESONANCE_ROUTE_CHOSEN',
                       min(resolution.server_time),
                       'AUTHORITATIVE'
                FROM processed_event_resolution resolution
                WHERE resolution.event_id = :mirrorEventId
                  AND resolution.choice_id = :routeChoiceId
                GROUP BY resolution.user_id

                UNION ALL

                SELECT resolution.user_id,
                       'RESONANCE_ROUTE_COMPLETED',
                       min(resolution.server_time),
                       'AUTHORITATIVE'
                FROM processed_event_resolution resolution
                WHERE resolution.event_id = :routeEventId
                GROUP BY resolution.user_id
            )
            """;

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public CompassJourneyAnalyticsService(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public CompassJourneyAnalyticsSnapshot summary(String cohortCode) {
        String normalizedCohort = normalizeCohort(cohortCode);
        MapSqlParameterSource parameters = parameters(normalizedCohort);
        SnapshotObservation observation = observeSnapshot(parameters);
        long eligibleUsers = observation.eligibleUsers();
        long instrumentedUsers = instrumentedUsers(parameters);

        CompassJourneyFunnel crafting = funnel(
                parameters,
                eligibleUsers,
                CompassJourneyFunnelId.CRAFTING_EQUIPMENT,
                CompassJourneyStage.RECIPE_SEEN,
                List.of(
                        CompassJourneyStage.RECIPE_READY_SEEN,
                        CompassJourneyStage.COMPASS_CRAFTED,
                        CompassJourneyStage.COMPASS_EQUIPPED
                )
        );
        CompassJourneyFunnel route = funnel(
                parameters,
                eligibleUsers,
                CompassJourneyFunnelId.RESONANCE_ROUTE,
                CompassJourneyStage.MIRROR_DELTA_REACHED,
                List.of(
                        CompassJourneyStage.ROUTE_LOCKED_SEEN,
                        CompassJourneyStage.ROUTE_AVAILABLE_SEEN,
                        CompassJourneyStage.RESONANCE_ROUTE_CHOSEN,
                        CompassJourneyStage.RESONANCE_ROUTE_COMPLETED
                )
        );
        List<CompassJourneyFunnel> funnels = List.of(crafting, route);
        CompassJourneyDataQuality dataQuality = dataQuality(
                parameters,
                funnels
        );

        return new CompassJourneyAnalyticsSnapshot(
                normalizedCohort,
                eligibleUsers,
                instrumentedUsers,
                ratio(instrumentedUsers, eligibleUsers),
                funnels,
                dataQuality,
                observation.generatedAt()
        );
    }

    private SnapshotObservation observeSnapshot(
            MapSqlParameterSource parameters
    ) {
        SnapshotObservation observation = jdbcTemplate.queryForObject("""
                SELECT count(*) AS eligible_users,
                       statement_timestamp() AS generated_at
                FROM app_user subject
                WHERE
                """ + COHORT_FILTER, parameters, (resultSet, rowNumber) ->
                new SnapshotObservation(
                        resultSet.getLong("eligible_users"),
                        resultSet.getTimestamp("generated_at").toInstant()
                ));
        if (observation == null) {
            throw new IllegalStateException(
                    "Compass journey snapshot observation query returned no row"
            );
        }
        return observation;
    }

    private long instrumentedUsers(MapSqlParameterSource parameters) {
        Long result = jdbcTemplate.queryForObject(STAGE_EVENTS + """
                SELECT count(DISTINCT event.user_id)
                FROM compass_stage_event event
                JOIN app_user subject ON subject.user_id = event.user_id
                WHERE event.source = 'CLIENT_REPORTED'
                  AND
                """ + COHORT_FILTER, parameters, Long.class);
        return value(result);
    }

    private CompassJourneyFunnel funnel(
            MapSqlParameterSource baseParameters,
            long eligibleUsers,
            CompassJourneyFunnelId funnelId,
            CompassJourneyStage startStage,
            List<CompassJourneyStage> stages
    ) {
        MapSqlParameterSource parameters = copy(baseParameters)
                .addValue("startStage", startStage.name());
        Long started = jdbcTemplate.queryForObject(STAGE_EVENTS + """
                SELECT count(*)
                FROM compass_stage_event start_event
                JOIN app_user subject ON subject.user_id = start_event.user_id
                WHERE start_event.stage = :startStage
                  AND
                """ + COHORT_FILTER, parameters, Long.class);
        long startedUsers = value(started);
        List<CompassJourneyStageMetric> metrics = stages.stream()
                .map(stage -> stageMetric(
                        baseParameters,
                        startStage,
                        startedUsers,
                        stage
                ))
                .toList();
        return new CompassJourneyFunnel(
                funnelId,
                startStage,
                startStage.source(),
                startedUsers,
                Math.max(0, eligibleUsers - startedUsers),
                ratio(startedUsers, eligibleUsers),
                metrics
        );
    }

    private CompassJourneyStageMetric stageMetric(
            MapSqlParameterSource baseParameters,
            CompassJourneyStage startStage,
            long startedUsers,
            CompassJourneyStage targetStage
    ) {
        MapSqlParameterSource parameters = copy(baseParameters)
                .addValue("startStage", startStage.name())
                .addValue("targetStage", targetStage.name());
        StageRow row = jdbcTemplate.queryForObject(STAGE_EVENTS + """
                , started AS (
                    SELECT start_event.user_id,
                           start_event.occurred_at
                    FROM compass_stage_event start_event
                    JOIN app_user subject ON subject.user_id = start_event.user_id
                    WHERE start_event.stage = :startStage
                      AND
                """ + COHORT_FILTER + """
                )
                SELECT count(target.user_id) AS reached_users,
                       count(target.user_id) FILTER (
                           WHERE target.occurred_at >= started.occurred_at
                       ) AS ordered_users,
                       percentile_cont(0.5) WITHIN GROUP (
                           ORDER BY extract(
                               epoch FROM target.occurred_at - started.occurred_at
                           )
                       ) FILTER (
                           WHERE target.occurred_at >= started.occurred_at
                       ) AS median_seconds,
                       percentile_cont(0.9) WITHIN GROUP (
                           ORDER BY extract(
                               epoch FROM target.occurred_at - started.occurred_at
                           )
                       ) FILTER (
                           WHERE target.occurred_at >= started.occurred_at
                       ) AS p90_seconds
                FROM started
                LEFT JOIN compass_stage_event target
                  ON target.user_id = started.user_id
                 AND target.stage = :targetStage
                """, parameters, (resultSet, rowNumber) -> new StageRow(
                resultSet.getLong("reached_users"),
                resultSet.getLong("ordered_users"),
                nullableRoundedLong(resultSet.getObject("median_seconds")),
                nullableRoundedLong(resultSet.getObject("p90_seconds"))
        ));
        if (row == null) {
            throw new IllegalStateException("Compass journey analytics query returned no row");
        }
        return new CompassJourneyStageMetric(
                targetStage,
                targetStage.source(),
                row.reachedUsers(),
                Math.max(0, startedUsers - row.reachedUsers()),
                row.orderedUsers(),
                Math.max(0, row.reachedUsers() - row.orderedUsers()),
                ratio(row.reachedUsers(), startedUsers),
                ratio(row.orderedUsers(), startedUsers),
                row.medianSeconds(),
                row.p90Seconds()
        );
    }

    private CompassJourneyDataQuality dataQuality(
            MapSqlParameterSource parameters,
            List<CompassJourneyFunnel> funnels
    ) {
        SourceCounts counts = jdbcTemplate.queryForObject(STAGE_EVENTS + """
                SELECT count(*) FILTER (
                           WHERE event.source = 'CLIENT_REPORTED'
                       ) AS client_records,
                       count(*) FILTER (
                           WHERE event.source = 'AUTHORITATIVE'
                       ) AS authoritative_records
                FROM compass_stage_event event
                JOIN app_user subject ON subject.user_id = event.user_id
                WHERE
                """ + COHORT_FILTER, parameters, (resultSet, rowNumber) ->
                new SourceCounts(
                        resultSet.getLong("client_records"),
                        resultSet.getLong("authoritative_records")
                ));
        if (counts == null) {
            throw new IllegalStateException("Compass journey data-quality query returned no row");
        }
        long outOfOrderPairs = funnels.stream()
                .flatMap(funnel -> funnel.stages().stream())
                .mapToLong(CompassJourneyStageMetric::outOfOrderUsers)
                .sum();
        return new CompassJourneyDataQuality(
                counts.clientRecords(),
                counts.authoritativeRecords(),
                outOfOrderPairs,
                targetsWithoutStart(
                        parameters,
                        CompassJourneyStage.RECIPE_SEEN,
                        List.of(
                                CompassJourneyStage.COMPASS_CRAFTED,
                                CompassJourneyStage.COMPASS_EQUIPPED
                        )
                ),
                targetsWithoutStart(
                        parameters,
                        CompassJourneyStage.MIRROR_DELTA_REACHED,
                        List.of(
                                CompassJourneyStage.RESONANCE_ROUTE_CHOSEN,
                                CompassJourneyStage.RESONANCE_ROUTE_COMPLETED
                        )
                )
        );
    }

    private long targetsWithoutStart(
            MapSqlParameterSource baseParameters,
            CompassJourneyStage startStage,
            List<CompassJourneyStage> targetStages
    ) {
        MapSqlParameterSource parameters = copy(baseParameters)
                .addValue("startStage", startStage.name())
                .addValue(
                        "targetStages",
                        targetStages.stream().map(Enum::name).toList()
                );
        Long result = jdbcTemplate.queryForObject(STAGE_EVENTS + """
                SELECT count(DISTINCT target.user_id)
                FROM compass_stage_event target
                JOIN app_user subject ON subject.user_id = target.user_id
                WHERE target.stage IN (:targetStages)
                  AND
                """ + COHORT_FILTER + """
                  AND NOT EXISTS (
                      SELECT 1
                      FROM compass_stage_event start_event
                      WHERE start_event.user_id = target.user_id
                        AND start_event.stage = :startStage
                  )
                """, parameters, Long.class);
        return value(result);
    }

    private MapSqlParameterSource parameters(String cohortCode) {
        return new MapSqlParameterSource()
                .addValue("cohortCode", cohortCode)
                .addValue("contractVersion", TELEMETRY_CONTRACT_VERSION)
                .addValue(
                        "recipeId",
                        StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID
                )
                .addValue(
                        "compassItemId",
                        StarterInventoryContent.RESONANCE_COMPASS_ID
                )
                .addValue(
                        "navigationSlotId",
                        StarterEquipmentContent.NAVIGATION_SLOT_ID
                )
                .addValue(
                        "mirrorEventId",
                        StarterExpeditionContent.MIRROR_DELTA_EVENT_ID
                )
                .addValue(
                        "routeContentVersion",
                        StarterExpeditionContent.CONTENT_VERSION
                )
                .addValue(
                        "routeChoiceId",
                        StarterExpeditionContent.RESONANCE_ROUTE_CHOICE_ID
                )
                .addValue(
                        "routeEventId",
                        StarterExpeditionContent.RESONANCE_ROUTE_EVENT_ID
                );
    }

    private MapSqlParameterSource copy(MapSqlParameterSource source) {
        MapSqlParameterSource copy = new MapSqlParameterSource();
        for (String name : source.getParameterNames()) {
            copy.addValue(name, source.getValue(name));
        }
        return copy;
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
                    "Unexpected percentile value type: "
                            + value.getClass().getName()
            );
        }
        return Math.round(number.doubleValue());
    }

    private record StageRow(
            long reachedUsers,
            long orderedUsers,
            Long medianSeconds,
            Long p90Seconds
    ) {
    }

    private record SourceCounts(long clientRecords, long authoritativeRecords) {
    }

    private record SnapshotObservation(long eligibleUsers, Instant generatedAt) {
    }
}
