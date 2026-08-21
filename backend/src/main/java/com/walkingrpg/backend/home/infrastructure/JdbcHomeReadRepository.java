package com.walkingrpg.backend.home.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyChronicleTotals;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyDecisionOutcomeSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyEvent;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyFinaleOutcomeSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyHistory;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyPilotExperienceRewardSnapshot;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.InventoryRuntimeItem;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
import com.walkingrpg.backend.home.domain.PetBondRewardSnapshot;
import com.walkingrpg.backend.progression.application.ActivePetProvider;
import com.walkingrpg.backend.progression.application.ActivePetSelection;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcHomeReadRepository implements HomeReadRepository {

    private final JdbcTemplate jdbcTemplate;
    private final StarterProgressionContent progressionContent;
    private final ActivePetProvider activePetProvider;
    private final EventResolutionRepository eventResolutionRepository;

    public JdbcHomeReadRepository(
            JdbcTemplate jdbcTemplate,
            StarterProgressionContent progressionContent,
            ActivePetProvider activePetProvider,
            EventResolutionRepository eventResolutionRepository
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.progressionContent = progressionContent;
        this.activePetProvider = activePetProvider;
        this.eventResolutionRepository = eventResolutionRepository;
    }

    @Override
    public Optional<ProcessedEventResolution> findPendingEventResult(
            String userId,
            String expeditionId
    ) {
        return eventResolutionRepository.findPendingResult(userId, expeditionId);
    }

    @Override
    public List<ExpeditionJourneyEvent> findJourneyEvents(
            String userId,
            String expeditionId,
            long journeyNumber
    ) {
        return jdbcTemplate.query("""
                SELECT event_id,
                       event_title,
                       choice_id,
                       choice_title,
                       outcome_title,
                       outcome_summary,
                       pilot_experience_gained,
                       pilot_id,
                       pilot_name,
                       pet_id,
                       pet_name,
                       pet_bond_gained,
                       material_item_id,
                       material_item_name,
                       material_quantity_gained,
                       server_time
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND journey_number = ?
                ORDER BY expedition_version, receipt_id
                """, (resultSet, rowNumber) -> journeyEvent(resultSet),
                userId, expeditionId, journeyNumber);
    }

    @Override
    public Optional<Instant> findJourneyStartedAt(
            String userId,
            String expeditionId,
            long journeyNumber
    ) {
        if (journeyNumber <= 0) {
            throw new IllegalArgumentException(
                    "Номер похода должен быть положительным"
            );
        }
        return jdbcTemplate.query("""
                SELECT CASE
                           WHEN ? = 1 THEN COALESCE(
                               cycle.created_at,
                               progress.created_at
                           )
                           ELSE (
                               SELECT journey_start.server_time
                               FROM processed_expedition_journey_start
                                    journey_start
                               WHERE journey_start.user_id = progress.user_id
                                 AND journey_start.expedition_id =
                                         progress.expedition_id
                                 AND journey_start.journey_number = ?
                               ORDER BY journey_start.expedition_version,
                                        journey_start.created_at,
                                        journey_start.idempotency_key
                               LIMIT 1
                           )
                       END AS started_at
                FROM expedition_progress progress
                LEFT JOIN expedition_journey_cycle cycle
                  ON cycle.user_id = progress.user_id
                 AND cycle.expedition_id = progress.expedition_id
                WHERE progress.user_id = ?
                  AND progress.expedition_id = ?
                """, resultSet -> {
            if (!resultSet.next()) {
                return Optional.empty();
            }
            Timestamp startedAt = resultSet.getTimestamp("started_at");
            return startedAt == null
                    ? Optional.empty()
                    : Optional.of(startedAt.toInstant());
        }, journeyNumber, journeyNumber, userId, expeditionId);
    }

    @Override
    public List<ExpeditionJourneyHistory> findRecentCompletedJourneys(
            String userId,
            String expeditionId,
            long currentJourneyNumber,
            int limit
    ) {
        return jdbcTemplate.query("""
                WITH recent_completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                    ORDER BY completed_journey_number DESC
                    LIMIT ?
                ),
                recent_completed_with_start AS (
                    SELECT completed.completed_journey_number,
                           CASE
                               WHEN completed.completed_journey_number = 1
                               THEN (
                                   SELECT COALESCE(
                                       cycle.created_at,
                                       progress.created_at
                                   )
                                   FROM expedition_progress progress
                                   LEFT JOIN expedition_journey_cycle cycle
                                     ON cycle.user_id = progress.user_id
                                    AND cycle.expedition_id =
                                            progress.expedition_id
                                   WHERE progress.user_id = ?
                                     AND progress.expedition_id = ?
                               )
                               ELSE (
                                   SELECT journey_start.server_time
                                   FROM processed_expedition_journey_start
                                        journey_start
                                   WHERE journey_start.user_id = ?
                                     AND journey_start.expedition_id = ?
                                     AND journey_start.journey_number =
                                             completed.completed_journey_number
                                   ORDER BY journey_start.expedition_version,
                                            journey_start.created_at,
                                            journey_start.idempotency_key
                                   LIMIT 1
                               )
                           END AS started_at
                    FROM recent_completed_journey completed
                )
                SELECT resolution.journey_number,
                       completed.started_at,
                       resolution.event_id,
                       resolution.event_title,
                       resolution.choice_id,
                       resolution.choice_title,
                       resolution.outcome_title,
                       resolution.outcome_summary,
                       resolution.pilot_experience_gained,
                       resolution.pilot_id,
                       resolution.pilot_name,
                       resolution.pet_id,
                       resolution.pet_name,
                       resolution.pet_bond_gained,
                       resolution.material_item_id,
                       resolution.material_item_name,
                       resolution.material_quantity_gained,
                       resolution.server_time
                FROM recent_completed_with_start completed
                JOIN processed_event_resolution resolution
                 ON resolution.user_id = ?
                 AND resolution.expedition_id = ?
                 AND resolution.journey_number =
                         completed.completed_journey_number
                ORDER BY resolution.journey_number DESC,
                         resolution.expedition_version,
                         resolution.receipt_id
                """, resultSet -> {
            List<ExpeditionJourneyHistory> histories = new ArrayList<>();
            List<ExpeditionJourneyEvent> events = null;
            long journeyNumber = -1;
            Instant startedAt = null;
            while (resultSet.next()) {
                long rowJourneyNumber = resultSet.getLong("journey_number");
                if (rowJourneyNumber != journeyNumber) {
                    if (events != null) {
                        histories.add(new ExpeditionJourneyHistory(
                                journeyNumber,
                                startedAt,
                                events
                        ));
                    }
                    journeyNumber = rowJourneyNumber;
                    Timestamp rowStartedAt = resultSet.getTimestamp(
                            "started_at"
                    );
                    startedAt = rowStartedAt == null
                            ? null
                            : rowStartedAt.toInstant();
                    events = new ArrayList<>();
                }
                events.add(journeyEvent(resultSet));
            }
            if (events != null) {
                histories.add(new ExpeditionJourneyHistory(
                        journeyNumber,
                        startedAt,
                        events
                ));
            }
            return List.copyOf(histories);
        }, userId, expeditionId, currentJourneyNumber, limit,
                userId, expeditionId, userId, expeditionId,
                userId, expeditionId);
    }

    @Override
    public ExpeditionJourneyChronicleTotals findCompletedJourneyChronicle(
            String userId,
            String expeditionId,
            long currentJourneyNumber
    ) {
        ExpeditionJourneyChronicleTotals totals = jdbcTemplate.queryForObject("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                journey_boundary AS (
                    SELECT completed.completed_journey_number,
                           CASE
                               WHEN completed.completed_journey_number = 1
                               THEN (
                                   SELECT COALESCE(
                                       cycle.created_at,
                                       progress.created_at
                                   )
                                   FROM expedition_progress progress
                                   LEFT JOIN expedition_journey_cycle cycle
                                     ON cycle.user_id = progress.user_id
                                    AND cycle.expedition_id =
                                            progress.expedition_id
                                   WHERE progress.user_id = ?
                                     AND progress.expedition_id = ?
                               )
                               ELSE (
                                   SELECT journey_start.server_time
                                   FROM processed_expedition_journey_start
                                        journey_start
                                   WHERE journey_start.user_id = ?
                                     AND journey_start.expedition_id = ?
                                     AND journey_start.journey_number =
                                             completed.completed_journey_number
                                   ORDER BY journey_start.expedition_version,
                                            journey_start.created_at,
                                            journey_start.idempotency_key
                                   LIMIT 1
                               )
                           END AS started_at,
                           (
                               SELECT final_resolution.server_time
                               FROM processed_event_resolution
                                    final_resolution
                               WHERE final_resolution.user_id = ?
                                 AND final_resolution.expedition_id = ?
                                 AND final_resolution.journey_number =
                                         completed.completed_journey_number
                               ORDER BY final_resolution.expedition_version DESC,
                                        final_resolution.receipt_id DESC
                               LIMIT 1
                           ) AS resolved_at
                    FROM completed_journey completed
                ),
                duration_stats AS (
                    SELECT CASE
                               WHEN COUNT(*) = 0 THEN 0::BIGINT
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN SUM(FLOOR(EXTRACT(
                                   EPOCH FROM (resolved_at - started_at)
                               )))::BIGINT
                               ELSE NULL
                           END AS total_duration_seconds,
                           CASE
                               WHEN COUNT(*) = 0 THEN 0::BIGINT
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN MIN(FLOOR(EXTRACT(
                                   EPOCH FROM (resolved_at - started_at)
                               )))::BIGINT
                               ELSE NULL
                           END AS shortest_duration_seconds,
                           CASE
                               WHEN COUNT(*) = 0 THEN NULL::BIGINT
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN (
                                   SELECT winner.completed_journey_number
                                   FROM journey_boundary winner
                                   ORDER BY FLOOR(EXTRACT(
                                       EPOCH FROM (
                                           winner.resolved_at
                                           - winner.started_at
                                       )
                                   )),
                                   winner.completed_journey_number
                                   LIMIT 1
                               )
                               ELSE NULL
                           END AS shortest_journey_number,
                           CASE
                               WHEN COUNT(*) = 0 THEN NULL::TIMESTAMPTZ
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN (
                                   SELECT winner.resolved_at
                                   FROM journey_boundary winner
                                   ORDER BY FLOOR(EXTRACT(
                                       EPOCH FROM (
                                           winner.resolved_at
                                           - winner.started_at
                                       )
                                   )),
                                   winner.completed_journey_number
                                   LIMIT 1
                               )
                               ELSE NULL
                           END AS shortest_journey_completed_at,
                           CASE
                               WHEN COUNT(*) = 0 THEN 0::BIGINT
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN MAX(FLOOR(EXTRACT(
                                   EPOCH FROM (resolved_at - started_at)
                               )))::BIGINT
                               ELSE NULL
                           END AS longest_duration_seconds,
                           CASE
                               WHEN COUNT(*) = 0 THEN NULL::BIGINT
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN (
                                   SELECT winner.completed_journey_number
                                   FROM journey_boundary winner
                                   ORDER BY FLOOR(EXTRACT(
                                       EPOCH FROM (
                                           winner.resolved_at
                                           - winner.started_at
                                       )
                                   )) DESC,
                                   winner.completed_journey_number
                                   LIMIT 1
                               )
                               ELSE NULL
                           END AS longest_journey_number,
                           CASE
                               WHEN COUNT(*) = 0 THEN NULL::TIMESTAMPTZ
                               WHEN COUNT(*) = COUNT(*) FILTER (
                                   WHERE started_at IS NOT NULL
                                     AND resolved_at IS NOT NULL
                                     AND resolved_at >= started_at
                               ) THEN (
                                   SELECT winner.resolved_at
                                   FROM journey_boundary winner
                                   ORDER BY FLOOR(EXTRACT(
                                       EPOCH FROM (
                                           winner.resolved_at
                                           - winner.started_at
                                       )
                                   )) DESC,
                                   winner.completed_journey_number
                                   LIMIT 1
                               )
                               ELSE NULL
                           END AS longest_journey_completed_at
                    FROM journey_boundary
                )
                SELECT COUNT(DISTINCT completed.completed_journey_number)
                           AS completed_journey_count,
                       COUNT(resolution.event_id) AS decision_count,
                       (
                           SELECT total_duration_seconds
                           FROM duration_stats
                       ) AS total_duration_seconds,
                       (
                           SELECT shortest_duration_seconds
                           FROM duration_stats
                       ) AS shortest_duration_seconds,
                       (
                           SELECT shortest_journey_number
                           FROM duration_stats
                       ) AS shortest_journey_number,
                       (
                           SELECT shortest_journey_completed_at
                           FROM duration_stats
                       ) AS shortest_journey_completed_at,
                       (
                           SELECT longest_duration_seconds
                           FROM duration_stats
                       ) AS longest_duration_seconds,
                       (
                           SELECT longest_journey_number
                           FROM duration_stats
                       ) AS longest_journey_number,
                       (
                           SELECT longest_journey_completed_at
                           FROM duration_stats
                       ) AS longest_journey_completed_at,
                       COALESCE(SUM(
                           resolution.pilot_experience_gained
                       ), 0) AS pilot_experience_gained,
                       COALESCE(SUM(
                           resolution.pet_bond_gained
                       ), 0) AS pet_bond_gained
                FROM completed_journey completed
                LEFT JOIN processed_event_resolution resolution
                  ON resolution.user_id = ?
                 AND resolution.expedition_id = ?
                 AND resolution.journey_number =
                         completed.completed_journey_number
                """, (resultSet, rowNumber) -> {
                        Timestamp shortestJourneyCompletedAt =
                                resultSet.getTimestamp(
                                        "shortest_journey_completed_at"
                                );
                        Timestamp longestJourneyCompletedAt =
                                resultSet.getTimestamp(
                                        "longest_journey_completed_at"
                                );
                        return new ExpeditionJourneyChronicleTotals(
                                resultSet.getLong(
                                        "completed_journey_count"
                                ),
                                resultSet.getLong("decision_count"),
                                resultSet.getObject(
                                        "total_duration_seconds",
                                        Long.class
                                ),
                                resultSet.getObject(
                                        "shortest_duration_seconds",
                                        Long.class
                                ),
                                resultSet.getObject(
                                        "shortest_journey_number",
                                        Long.class
                                ),
                                shortestJourneyCompletedAt == null
                                        ? null
                                        : shortestJourneyCompletedAt.toInstant(),
                                resultSet.getObject(
                                        "longest_duration_seconds",
                                        Long.class
                                ),
                                resultSet.getObject(
                                        "longest_journey_number",
                                        Long.class
                                ),
                                longestJourneyCompletedAt == null
                                        ? null
                                        : longestJourneyCompletedAt.toInstant(),
                                resultSet.getLong(
                                        "pilot_experience_gained"
                                ),
                                resultSet.getLong("pet_bond_gained"),
                                List.of(),
                                List.of(),
                                List.of(),
                                List.of(),
                                List.of()
                        );
                },
                userId,
                expeditionId,
                currentJourneyNumber,
                userId,
                expeditionId,
                userId,
                expeditionId,
                userId,
                expeditionId,
                userId,
                expeditionId
        );
        List<ExpeditionJourneyPilotExperienceRewardSnapshot>
                pilotExperienceRewards = jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                eligible_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.pilot_id,
                           resolution.pilot_name,
                           resolution.pilot_experience_gained
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                    WHERE resolution.pilot_experience_gained > 0
                ),
                ordered_pilot AS (
                    SELECT pilot_id,
                           pilot_name,
                           SUM(pilot_experience_gained) OVER (
                               PARTITION BY pilot_id, pilot_name
                           ) AS experience_gained,
                           ROW_NUMBER() OVER (
                               PARTITION BY pilot_id, pilot_name
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM eligible_resolution
                )
                SELECT pilot_id,
                       pilot_name,
                       experience_gained
                FROM ordered_pilot
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) ->
                        new ExpeditionJourneyPilotExperienceRewardSnapshot(
                                resultSet.getString("pilot_id"),
                                resultSet.getString("pilot_name"),
                                resultSet.getLong("experience_gained")
                        ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        List<PetBondRewardSnapshot> petBondRewards = jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                eligible_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.pet_id,
                           resolution.pet_name,
                           resolution.pet_bond_gained
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                    WHERE resolution.pet_bond_gained > 0
                ),
                ordered_pet AS (
                    SELECT pet_id,
                           pet_name,
                           SUM(pet_bond_gained) OVER (
                               PARTITION BY pet_id, pet_name
                           ) AS bond_gained,
                           ROW_NUMBER() OVER (
                               PARTITION BY pet_id, pet_name
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM eligible_resolution
                )
                SELECT pet_id,
                       pet_name,
                       bond_gained
                FROM ordered_pet
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) -> new PetBondRewardSnapshot(
                        resultSet.getString("pet_id"),
                        resultSet.getString("pet_name"),
                        resultSet.getLong("bond_gained")
                ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        List<MaterialRewardPreviewSnapshot> materials = jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                eligible_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.material_item_id,
                           resolution.material_item_name,
                           resolution.material_quantity_gained
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                    WHERE resolution.material_quantity_gained > 0
                ),
                ordered_material AS (
                    SELECT material_item_id,
                           material_item_name,
                           SUM(material_quantity_gained) OVER (
                               PARTITION BY material_item_id,
                                            material_item_name
                           ) AS quantity,
                           ROW_NUMBER() OVER (
                               PARTITION BY material_item_id,
                                            material_item_name
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM eligible_resolution
                )
                SELECT material_item_id,
                       material_item_name,
                       quantity
                FROM ordered_material
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) ->
                        new MaterialRewardPreviewSnapshot(
                                resultSet.getString("material_item_id"),
                                resultSet.getString("material_item_name"),
                                resultSet.getLong("quantity")
                ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        List<ExpeditionJourneyDecisionOutcomeSnapshot> decisionOutcomes =
                jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                eligible_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.event_id,
                           resolution.event_title,
                           resolution.choice_id,
                           resolution.choice_title,
                           resolution.outcome_title
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                ),
                ordered_decision AS (
                    SELECT event_id,
                           event_title,
                           choice_id,
                           choice_title,
                           outcome_title,
                           COUNT(*) OVER (
                               PARTITION BY event_id,
                                            event_title,
                                            choice_id,
                                            choice_title,
                                            outcome_title
                           ) AS decision_count,
                           ROW_NUMBER() OVER (
                               PARTITION BY event_id,
                                            event_title,
                                            choice_id,
                                            choice_title,
                                            outcome_title
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM eligible_resolution
                )
                SELECT event_id,
                       event_title,
                       choice_id,
                       choice_title,
                       outcome_title,
                       decision_count
                FROM ordered_decision
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) ->
                        new ExpeditionJourneyDecisionOutcomeSnapshot(
                                resultSet.getString("event_id"),
                                resultSet.getString("event_title"),
                                resultSet.getString("choice_id"),
                                resultSet.getString("choice_title"),
                                resultSet.getString("outcome_title"),
                                resultSet.getLong("decision_count")
                        ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        List<ExpeditionJourneyFinaleOutcomeSnapshot> finaleOutcomes =
                jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                ranked_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.event_id,
                           resolution.event_title,
                           resolution.choice_id,
                           resolution.choice_title,
                           resolution.outcome_title,
                           ROW_NUMBER() OVER (
                               PARTITION BY resolution.journey_number
                               ORDER BY resolution.expedition_version DESC,
                                        resolution.receipt_id DESC
                           ) AS journey_row
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                ),
                final_resolution AS (
                    SELECT journey_number,
                           expedition_version,
                           receipt_id,
                           event_id,
                           event_title,
                           choice_id,
                           choice_title,
                           outcome_title
                    FROM ranked_resolution
                    WHERE journey_row = 1
                ),
                ordered_finale AS (
                    SELECT event_id,
                           event_title,
                           choice_id,
                           choice_title,
                           outcome_title,
                           COUNT(*) OVER (
                               PARTITION BY event_id,
                                            event_title,
                                            choice_id,
                                            choice_title,
                                            outcome_title
                           ) AS journey_count,
                           ROW_NUMBER() OVER (
                               PARTITION BY event_id,
                                            event_title,
                                            choice_id,
                                            choice_title,
                                            outcome_title
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM final_resolution
                )
                SELECT event_id,
                       event_title,
                       choice_id,
                       choice_title,
                       outcome_title,
                       journey_count
                FROM ordered_finale
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) ->
                        new ExpeditionJourneyFinaleOutcomeSnapshot(
                                resultSet.getString("event_id"),
                                resultSet.getString("event_title"),
                                resultSet.getString("choice_id"),
                                resultSet.getString("choice_title"),
                                resultSet.getString("outcome_title"),
                                resultSet.getLong("journey_count")
                        ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        return new ExpeditionJourneyChronicleTotals(
                totals.completedJourneyCount(),
                totals.decisionCount(),
                totals.totalDurationSeconds(),
                totals.shortestDurationSeconds(),
                totals.shortestJourneyNumber(),
                totals.shortestJourneyCompletedAt(),
                totals.longestDurationSeconds(),
                totals.longestJourneyNumber(),
                totals.longestJourneyCompletedAt(),
                totals.pilotExperienceGained(),
                totals.petBondGained(),
                pilotExperienceRewards,
                petBondRewards,
                materials,
                decisionOutcomes,
                finaleOutcomes
        );
    }

    private ExpeditionJourneyEvent journeyEvent(
            ResultSet resultSet
    ) throws SQLException {
        Long materialQuantity = resultSet.getObject(
                "material_quantity_gained",
                Long.class
        );
        MaterialRewardPreviewSnapshot material = materialQuantity == null
                ? null
                : new MaterialRewardPreviewSnapshot(
                        resultSet.getString("material_item_id"),
                        resultSet.getString("material_item_name"),
                        materialQuantity
                );
        return new ExpeditionJourneyEvent(
                resultSet.getString("event_id"),
                resultSet.getString("event_title"),
                resultSet.getString("choice_id"),
                resultSet.getString("choice_title"),
                resultSet.getString("outcome_title"),
                resultSet.getString("outcome_summary"),
                resultSet.getInt("pilot_experience_gained"),
                resultSet.getString("pilot_id"),
                resultSet.getString("pilot_name"),
                resultSet.getString("pet_id"),
                resultSet.getString("pet_name"),
                resultSet.getInt("pet_bond_gained"),
                material,
                resultSet.getTimestamp("server_time").toInstant()
        );
    }

    @Override
    public HomeRuntimeState findState(
            String userId,
            LocalDate localDate,
            String expeditionId
    ) {
        ActivePetSelection activePet = activePetProvider.activePetFor(userId);
        String activePetId = activePet.petId();
        HomeRuntimeState state = jdbcTemplate.queryForObject("""
                SELECT COALESCE(activity.accepted_total, 0) AS daily_steps,
                       COALESCE(activity.state_version, 0) AS activity_state_version,
                       activity.time_zone,
                       activity.updated_at AS last_activity_sync_at,
                       COALESCE(wallet.balance, 0) AS available_energy,
                       COALESCE(wallet.version, 0) AS economy_version,
                       COALESCE(expedition.progress_energy, 0) AS expedition_progress,
                       COALESCE(expedition.required_energy, 0) AS expedition_required_energy,
                       expedition.status AS expedition_status,
                       COALESCE(expedition.version, 0) AS expedition_version,
                       COALESCE(journey.journey_number, 1) AS expedition_journey_number,
                       expedition.current_node_id,
                       expedition.unlocked_event_id,
                       (pilot.user_id IS NOT NULL) AS pilot_progress_present,
                       COALESCE(pilot.level, 0) AS pilot_level,
                       COALESCE(pilot.current_experience, 0) AS pilot_current_experience,
                       COALESCE(pilot.next_level_experience, 0) AS pilot_next_level_experience,
                       COALESCE(pet.level, 0) AS pet_level,
                       COALESCE(pet.bond, 0) AS pet_bond
                FROM (VALUES (1)) AS anchor(value)
                LEFT JOIN activity_sync_state activity
                  ON activity.user_id = ?
                 AND activity.local_date = ?
                LEFT JOIN economy_wallet wallet
                  ON wallet.user_id = ?
                 AND wallet.currency_code = 'ENERGY'
                LEFT JOIN expedition_progress expedition
                  ON expedition.user_id = ?
                 AND expedition.expedition_id = ?
                LEFT JOIN expedition_journey_cycle journey
                  ON journey.user_id = expedition.user_id
                 AND journey.expedition_id = expedition.expedition_id
                LEFT JOIN pilot_progress pilot
                  ON pilot.user_id = ?
                 AND pilot.pilot_id = ?
                LEFT JOIN pet_progress pet
                  ON pet.user_id = ?
                 AND pet.pet_id = ?
                """, (resultSet, rowNumber) -> {
            Timestamp lastSync = resultSet.getTimestamp("last_activity_sync_at");
            Instant lastActivitySyncAt = lastSync == null ? null : lastSync.toInstant();

            return new HomeRuntimeState(
                    resultSet.getLong("daily_steps"),
                    resultSet.getLong("activity_state_version"),
                    resultSet.getString("time_zone"),
                    lastActivitySyncAt,
                    resultSet.getLong("available_energy"),
                    resultSet.getLong("economy_version"),
                    resultSet.getLong("expedition_progress"),
                    resultSet.getLong("expedition_required_energy"),
                    resultSet.getString("expedition_status"),
                    resultSet.getLong("expedition_version"),
                    resultSet.getLong("expedition_journey_number"),
                    resultSet.getString("current_node_id"),
                    resultSet.getString("unlocked_event_id"),
                    resultSet.getBoolean("pilot_progress_present"),
                    resultSet.getInt("pilot_level"),
                    resultSet.getInt("pilot_current_experience"),
                    resultSet.getInt("pilot_next_level_experience"),
                    activePetId,
                    true,
                    Math.max(resultSet.getInt("pet_level"), activePet.level()),
                    Math.max(resultSet.getInt("pet_bond"), activePet.bond()),
                    activePet.evolutionStage(),
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    List.<InventoryRuntimeItem>of()
            );
        },
                userId,
                localDate,
                userId,
                userId,
                expeditionId,
                userId,
                progressionContent.pilot().pilotId(),
                userId,
                activePetId
        );

        if (state == null) {
            throw new IllegalStateException("Home read-model query не вернул строку");
        }
        return state.withInventory(findInventory(userId));
    }

    private List<InventoryRuntimeItem> findInventory(String userId) {
        return jdbcTemplate.query("""
                SELECT item_id,
                       quantity,
                       version,
                       item_instance_id,
                       equipped_slot_id,
                       rarity
                FROM (
                    SELECT item_id,
                           quantity,
                           version,
                           NULL::uuid AS item_instance_id,
                           NULL::varchar AS equipped_slot_id,
                           NULL::varchar AS rarity
                    FROM inventory_stack
                    WHERE user_id = ?
                      AND quantity > 0
                    UNION ALL
                    SELECT item.item_id,
                           1 AS quantity,
                           item.version,
                           item.item_instance_id,
                           equipment.slot_id AS equipped_slot_id,
                           item.rarity
                    FROM unique_inventory_item item
                    LEFT JOIN equipment_slot_state equipment
                      ON equipment.user_id = item.user_id
                     AND equipment.item_instance_id = item.item_instance_id
                    WHERE item.user_id = ?
                ) inventory
                ORDER BY item_id
                """, (resultSet, rowNumber) -> new InventoryRuntimeItem(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity"),
                resultSet.getLong("version"),
                resultSet.getObject("item_instance_id", java.util.UUID.class),
                resultSet.getString("equipped_slot_id"),
                resultSet.getString("rarity")
        ), userId, userId);
    }
}
