package com.walkingrpg.backend.platform.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.activity.retention.ActivityRetentionService;
import com.walkingrpg.backend.platform.push.PushDeliveryProvider;
import com.walkingrpg.backend.platform.push.PushDeliveryResult;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlatformAdminService {

    private static final Set<String> REQUIRED_CONFIG_KEYS = Set.of(
            "backgroundHealthSyncEnabled",
            "activityRetentionDays",
            "seasonId",
            "weeklyRouteEnergy",
            "sandboxPaymentsEnabled",
            "weeklyRouteEnabled"
    );

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final PushDeliveryProvider pushDeliveryProvider;
    private final ActivityRetentionService retentionService;
    private final AccountDeletionRegistry accountDeletionRegistry;
    private final Clock clock;

    public PlatformAdminService(
            JdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper,
            PushDeliveryProvider pushDeliveryProvider,
            ActivityRetentionService retentionService,
            AccountDeletionRegistry accountDeletionRegistry,
            Clock clock
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
        this.pushDeliveryProvider = pushDeliveryProvider;
        this.retentionService = retentionService;
        this.accountDeletionRegistry = accountDeletionRegistry;
        this.clock = clock;
    }

    @Transactional
    public void recordEvent(
            String userId,
            String eventName,
            Instant occurredAt,
            Map<String, Object> attributes
    ) {
        Instant receivedAt = now();
        if (hasText(userId)) {
            ensureUser(userId.trim(), receivedAt);
        }
        jdbcTemplate.update("""
                INSERT INTO platform_event (
                    user_id, event_name, occurred_at, attributes, received_at
                ) VALUES (?, ?, ?, ?::jsonb, ?)
                """,
                normalizeNullable(userId),
                requireText(eventName, "eventName"),
                Timestamp.from(occurredAt == null ? receivedAt : occurredAt),
                writeJson(attributes == null ? Map.of() : attributes),
                Timestamp.from(receivedAt)
        );
    }

    @Transactional
    public void recordCrash(
            String userId,
            String platform,
            String appVersion,
            String errorType,
            String message,
            String stackTrace,
            Map<String, Object> context,
            Instant occurredAt
    ) {
        Instant receivedAt = now();
        if (hasText(userId)) {
            ensureUser(userId.trim(), receivedAt);
        }
        jdbcTemplate.update("""
                INSERT INTO platform_crash_report (
                    user_id, platform, app_version, error_type, message,
                    stack_trace, context, occurred_at, received_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?::jsonb, ?, ?)
                """,
                normalizeNullable(userId),
                requireText(platform, "platform").toUpperCase(),
                requireText(appVersion, "appVersion"),
                requireText(errorType, "errorType"),
                requireText(message, "message"),
                normalizeNullable(stackTrace),
                writeJson(context == null ? Map.of() : context),
                Timestamp.from(occurredAt == null ? receivedAt : occurredAt),
                Timestamp.from(receivedAt)
        );
    }

    @Transactional
    public void registerPush(
            String userId,
            String deviceId,
            String platform,
            String provider,
            String token
    ) {
        Instant timestamp = now();
        ensureDevice(userId, deviceId, timestamp);
        jdbcTemplate.update("""
                INSERT INTO push_registration (
                    user_id, device_id, platform, provider, token_hash,
                    enabled, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, true, ?, ?)
                ON CONFLICT (user_id, device_id) DO UPDATE
                SET platform = EXCLUDED.platform,
                    provider = EXCLUDED.provider,
                    token_hash = EXCLUDED.token_hash,
                    enabled = true,
                    updated_at = EXCLUDED.updated_at
                """,
                requireText(userId, "userId"),
                requireText(deviceId, "deviceId"),
                requireText(platform, "platform").toUpperCase(),
                requireText(provider, "provider").toUpperCase(),
                sha256(requireText(token, "token")),
                Timestamp.from(timestamp),
                Timestamp.from(timestamp)
        );
    }

    @Transactional
    public Map<String, Object> updateRemoteConfig(
            String actor,
            String version,
            Map<String, Object> config
    ) {
        validateRemoteConfig(config);
        Instant timestamp = now();
        jdbcTemplate.update("UPDATE remote_config_snapshot SET is_active = false WHERE is_active");
        jdbcTemplate.update("""
                INSERT INTO remote_config_snapshot (
                    config_version, config_json, is_active, created_by, created_at
                ) VALUES (?, ?::jsonb, true, ?, ?)
                ON CONFLICT (config_version) DO UPDATE
                SET config_json = EXCLUDED.config_json,
                    is_active = true,
                    created_by = EXCLUDED.created_by,
                    created_at = EXCLUDED.created_at
                """,
                requireText(version, "version"),
                writeJson(config),
                requireText(actor, "actor"),
                Timestamp.from(timestamp)
        );
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("version", version);
        response.put("config", new LinkedHashMap<>(config));
        response.put("active", true);
        response.put("createdAt", timestamp);
        return response;
    }

    @Transactional
    public Map<String, Object> publishContent(
            String actor,
            String version,
            String releaseNotes,
            Map<String, Object> content
    ) {
        if (content == null || content.isEmpty()) {
            throw new PlatformValidationException("content не может быть пустым", "content");
        }
        Instant timestamp = now();
        jdbcTemplate.update("UPDATE content_release SET is_active = false WHERE is_active");
        jdbcTemplate.update("""
                INSERT INTO content_release (
                    content_version, release_notes, content_json,
                    is_active, created_by, created_at
                ) VALUES (?, ?, ?::jsonb, true, ?, ?)
                ON CONFLICT (content_version) DO UPDATE
                SET release_notes = EXCLUDED.release_notes,
                    content_json = EXCLUDED.content_json,
                    is_active = true,
                    created_by = EXCLUDED.created_by,
                    created_at = EXCLUDED.created_at
                """,
                requireText(version, "version"),
                requireText(releaseNotes, "releaseNotes"),
                writeJson(content),
                requireText(actor, "actor"),
                Timestamp.from(timestamp)
        );
        return Map.of(
                "contentVersion", version,
                "active", true,
                "createdAt", timestamp
        );
    }

    public List<Map<String, Object>> contentReleases() {
        return jdbcTemplate.query("""
                SELECT content_version, release_notes, is_active, created_by, created_at
                FROM content_release
                ORDER BY created_at DESC
                """, (resultSet, rowNumber) -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("contentVersion", resultSet.getString("content_version"));
            item.put("releaseNotes", resultSet.getString("release_notes"));
            item.put("active", resultSet.getBoolean("is_active"));
            item.put("createdBy", resultSet.getString("created_by"));
            item.put("createdAt", resultSet.getTimestamp("created_at").toInstant());
            return item;
        });
    }

    public List<Map<String, Object>> riskAssessments(int limit) {
        int normalizedLimit = Math.max(1, Math.min(limit, 500));
        return jdbcTemplate.query("""
                SELECT assessment_id, user_id, device_id, local_date,
                       authoritative_total, accepted_delta, risk_score,
                       decision, signals::text, created_at
                FROM activity_risk_assessment
                ORDER BY created_at DESC
                LIMIT ?
                """, (resultSet, rowNumber) -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("assessmentId", resultSet.getLong("assessment_id"));
            item.put("userId", resultSet.getString("user_id"));
            item.put("deviceId", resultSet.getString("device_id"));
            item.put("localDate", resultSet.getDate("local_date").toLocalDate());
            item.put("authoritativeTotal", resultSet.getLong("authoritative_total"));
            item.put("acceptedDelta", resultSet.getLong("accepted_delta"));
            item.put("riskScore", resultSet.getInt("risk_score"));
            item.put("decision", resultSet.getString("decision"));
            item.put("signals", readJson(resultSet.getString("signals")));
            item.put("createdAt", resultSet.getTimestamp("created_at").toInstant());
            return item;
        }, normalizedLimit);
    }

    public List<Map<String, Object>> crashReports(int limit) {
        int normalizedLimit = Math.max(1, Math.min(limit, 500));
        return jdbcTemplate.query("""
                SELECT report_id, user_id, platform, app_version, error_type,
                       message, stack_trace, context::text, occurred_at, received_at
                FROM platform_crash_report
                ORDER BY received_at DESC
                LIMIT ?
                """, (resultSet, rowNumber) -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("reportId", resultSet.getLong("report_id"));
            item.put("userId", resultSet.getString("user_id"));
            item.put("platform", resultSet.getString("platform"));
            item.put("appVersion", resultSet.getString("app_version"));
            item.put("errorType", resultSet.getString("error_type"));
            item.put("message", resultSet.getString("message"));
            item.put("stackTrace", resultSet.getString("stack_trace"));
            item.put("context", readJson(resultSet.getString("context")));
            item.put("occurredAt", resultSet.getTimestamp("occurred_at").toInstant());
            item.put("receivedAt", resultSet.getTimestamp("received_at").toInstant());
            return item;
        }, normalizedLimit);
    }

    public Map<String, Object> retentionSummary() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("cohortSize", queryLong("SELECT count(*) FROM app_user"));
        result.put("d1", retentionAtDay(1));
        result.put("d7", retentionAtDay(7));
        result.put("d30", retentionAtDay(30));
        result.put("onboarding", onboardingSummary());
        return result;
    }

    public PushDeliveryResult sendTestPush(String userId, String title, String body) {
        String normalizedUser = requireText(userId, "userId");
        Instant timestamp = now();
        ensureUser(normalizedUser, timestamp);
        PushDeliveryResult result = pushDeliveryProvider.send(
                normalizedUser,
                requireText(title, "title"),
                requireText(body, "body")
        );
        recordEvent(normalizedUser, "push_test_sent", timestamp, Map.of(
                "provider", result.provider(),
                "accepted", result.accepted(),
                "reference", result.reference()
        ));
        return result;
    }

    @Transactional
    public void upsertTester(
            String actor,
            String cohortCode,
            String userId,
            String status,
            String notes
    ) {
        Instant timestamp = now();
        ensureUser(userId, timestamp);
        jdbcTemplate.update("""
                INSERT INTO tester_cohort_member (
                    cohort_code, user_id, status, notes,
                    created_by, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (cohort_code, user_id) DO UPDATE
                SET status = EXCLUDED.status,
                    notes = EXCLUDED.notes,
                    updated_at = EXCLUDED.updated_at
                """,
                requireText(cohortCode, "cohortCode"),
                requireText(userId, "userId"),
                requireText(status, "status").toUpperCase(),
                normalizeNullable(notes),
                requireText(actor, "actor"),
                Timestamp.from(timestamp),
                Timestamp.from(timestamp)
        );
    }

    public List<Map<String, Object>> testers(String cohortCode) {
        return jdbcTemplate.query("""
                SELECT cohort_code, user_id, status, notes, created_by, created_at, updated_at
                FROM tester_cohort_member
                WHERE (? IS NULL OR cohort_code = ?)
                ORDER BY cohort_code, user_id
                """, (resultSet, rowNumber) -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("cohortCode", resultSet.getString("cohort_code"));
            item.put("userId", resultSet.getString("user_id"));
            item.put("status", resultSet.getString("status"));
            item.put("notes", resultSet.getString("notes"));
            item.put("createdBy", resultSet.getString("created_by"));
            item.put("createdAt", resultSet.getTimestamp("created_at").toInstant());
            item.put("updatedAt", resultSet.getTimestamp("updated_at").toInstant());
            return item;
        }, normalizeNullable(cohortCode), normalizeNullable(cohortCode));
    }

    public Map<String, Object> exportAccount(String userId) {
        String normalized = requireText(userId, "userId");
        Map<String, Object> export = new LinkedHashMap<>();
        export.put("exportedAt", now());
        export.put("user", jdbcTemplate.queryForList(
                "SELECT user_id, created_at, last_seen_at FROM app_user WHERE user_id = ?",
                normalized
        ));
        export.put("devices", jdbcTemplate.queryForList(
                "SELECT device_id, created_at, last_seen_at FROM app_device WHERE user_id = ?",
                normalized
        ));
        export.put("activity", jdbcTemplate.queryForList(
                "SELECT local_date, accepted_total, state_version, time_zone, updated_at "
                        + "FROM activity_sync_state WHERE user_id = ? ORDER BY local_date",
                normalized
        ));
        export.put("activityOperations", jdbcTemplate.queryForList(
                "SELECT device_id, idempotency_key, accepted_total, accepted_delta, "
                        + "energy_granted, energy_balance_after, economy_version, risk_status, "
                        + "state_version, server_time, created_at "
                        + "FROM processed_activity_sync WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("riskAssessments", jdbcTemplate.queryForList(
                "SELECT device_id, local_date, authoritative_total, accepted_delta, "
                        + "risk_score, decision, signals::text AS signals, created_at "
                        + "FROM activity_risk_assessment WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("wallet", jdbcTemplate.queryForList(
                "SELECT currency_code, balance, version, created_at, updated_at "
                        + "FROM economy_wallet WHERE user_id = ?",
                normalized
        ));
        export.put("economyLedger", jdbcTemplate.queryForList(
                "SELECT currency_code, amount, balance_after, wallet_version, reason_code, "
                        + "source_type, source_key, created_at "
                        + "FROM economy_ledger WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("expedition", jdbcTemplate.queryForList(
                "SELECT expedition_id, current_node_id, progress_energy, required_energy, "
                        + "status, unlocked_event_id, version, created_at, updated_at "
                        + "FROM expedition_progress WHERE user_id = ?",
                normalized
        ));
        export.put("expeditionOperations", jdbcTemplate.queryForList(
                "SELECT expedition_id, idempotency_key, content_version, expedition_name, "
                        + "energy_spent, energy_balance_after, economy_version, progress_after, "
                        + "required_energy, expedition_version, expedition_status, "
                        + "current_node_id, current_node_name, event_id, event_title, "
                        + "event_summary, server_time, created_at "
                        + "FROM processed_expedition_advance "
                        + "WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("pilotProgress", jdbcTemplate.queryForList(
                "SELECT pilot_id, level, current_experience, next_level_experience, "
                        + "version, created_at, updated_at "
                        + "FROM pilot_progress WHERE user_id = ? ORDER BY pilot_id",
                normalized
        ));
        export.put("petProgress", jdbcTemplate.queryForList(
                "SELECT pet_id, level, bond, version, created_at, updated_at "
                        + "FROM pet_progress WHERE user_id = ? ORDER BY pet_id",
                normalized
        ));
        export.put("eventResolutions", jdbcTemplate.queryForList(
                "SELECT expedition_id, event_id, idempotency_key, content_version, "
                        + "expedition_status, expedition_version, event_title, "
                        + "resolution_status, choice_id, choice_title, outcome_title, "
                        + "outcome_summary, pilot_id, pilot_name, pilot_level_after, "
                        + "pilot_experience_gained, pilot_experience_after, "
                        + "pilot_next_level_experience, pilot_version, pet_id, pet_name, "
                        + "pet_level_after, pet_bond_gained, pet_bond_after, pet_version, "
                        + "material_item_id, material_item_name, material_item_description, "
                        + "material_quantity_gained, material_quantity_after, material_version, "
                        + "server_time, created_at FROM processed_event_resolution "
                        + "WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("inventory", jdbcTemplate.queryForList(
                "SELECT item_id, quantity, version, created_at, updated_at "
                        + "FROM inventory_stack WHERE user_id = ? ORDER BY item_id",
                normalized
        ));
        export.put("inventoryLedger", jdbcTemplate.queryForList(
                "SELECT item_id, quantity_delta, quantity_after, inventory_version, "
                        + "reason_code, source_type, source_key, created_at "
                        + "FROM inventory_ledger WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("platformState", jdbcTemplate.queryForList(
                "SELECT state_json::text AS state_json, version, updated_at "
                        + "FROM roadmap_user_state WHERE user_id = ?",
                normalized
        ));
        export.put("platformCommands", jdbcTemplate.queryForList(
                "SELECT command_type, idempotency_key, response_json::text AS response_json, "
                        + "created_at "
                        + "FROM processed_roadmap_command WHERE user_id = ? ORDER BY created_at",
                normalized
        ));
        export.put("squadMembership", jdbcTemplate.queryForList(
                "SELECT squad.squad_id, squad.squad_name, "
                        + "(squad.owner_user_id = ?) AS owner, member.joined_at "
                        + "FROM roadmap_squad_member member "
                        + "JOIN roadmap_squad squad ON squad.squad_id = member.squad_id "
                        + "WHERE member.user_id = ?",
                normalized,
                normalized
        ));
        export.put("telemetry", jdbcTemplate.queryForList(
                "SELECT event_name, occurred_at, attributes::text AS attributes, received_at "
                        + "FROM platform_event WHERE user_id = ? ORDER BY occurred_at",
                normalized
        ));
        export.put("crashReports", jdbcTemplate.queryForList(
                "SELECT platform, app_version, error_type, message, stack_trace, "
                        + "context::text AS context, occurred_at, received_at "
                        + "FROM platform_crash_report WHERE user_id = ? ORDER BY occurred_at",
                normalized
        ));
        export.put("pushRegistrations", jdbcTemplate.queryForList(
                "SELECT device_id, platform, provider, enabled, created_at, updated_at "
                        + "FROM push_registration WHERE user_id = ?",
                normalized
        ));
        export.put("payments", jdbcTemplate.queryForList(
                "SELECT product_id, amount_minor, provider, provider_reference, status, "
                        + "created_at, updated_at FROM payment_intent WHERE user_id = ?",
                normalized
        ));
        export.put("testerCohorts", jdbcTemplate.queryForList(
                "SELECT cohort_code, status, notes, created_at, updated_at "
                        + "FROM tester_cohort_member WHERE user_id = ?",
                normalized
        ));
        return export;
    }

    @Transactional
    public AccountDeletionReceipt requestAccountDeletion(
            String userId,
            String idempotencyKey,
            String confirmation
    ) {
        String normalized = requireText(userId, "userId");
        String normalizedKey = requireText(idempotencyKey, "idempotencyKey");
        if (normalizedKey.length() > 128) {
            throw new PlatformValidationException(
                    "idempotencyKey не может быть длиннее 128 символов",
                    "idempotencyKey"
            );
        }
        if (!"DELETE".equals(confirmation)) {
            throw new PlatformValidationException(
                    "Для удаления аккаунта требуется точное подтверждение DELETE",
                    "confirmation"
            );
        }

        String subjectHash = accountDeletionRegistry.lockSubject(normalized);
        AccountDeletionReceipt existing = findDeletionReceipt(subjectHash, true);
        if (existing != null) {
            return existing;
        }

        Instant requestedAt = now();
        UUID receiptId = UUID.randomUUID();
        deleteAccountData(normalized);
        Instant completedAt = now();
        int inserted = jdbcTemplate.update("""
                INSERT INTO account_deletion_receipt (
                    subject_hash,
                    receipt_id,
                    request_key_hash,
                    requested_at,
                    completed_at
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT (subject_hash) DO NOTHING
                """,
                subjectHash,
                receiptId,
                sha256(normalizedKey),
                Timestamp.from(requestedAt),
                Timestamp.from(completedAt)
        );
        if (inserted == 0) {
            AccountDeletionReceipt replay = findDeletionReceipt(subjectHash, true);
            if (replay == null) {
                throw new IllegalStateException(
                        "Квитанция удаления не найдена после idempotent replay"
                );
            }
            return replay;
        }

        return new AccountDeletionReceipt(
                receiptId,
                "COMPLETED",
                requestedAt,
                completedAt,
                false
        );
    }

    private void deleteAccountData(String normalized) {
        List<String> ownedSquads = jdbcTemplate.query("""
                SELECT squad_id::text
                FROM roadmap_squad
                WHERE owner_user_id = ?
                """, (resultSet, rowNumber) -> resultSet.getString(1), normalized);
        for (String squadId : ownedSquads) {
            List<String> replacements = jdbcTemplate.query("""
                    SELECT user_id
                    FROM roadmap_squad_member
                    WHERE squad_id = ?::uuid
                      AND user_id <> ?
                    ORDER BY joined_at, user_id
                    LIMIT 1
                    """, (resultSet, rowNumber) -> resultSet.getString(1), squadId, normalized);
            if (replacements.isEmpty()) {
                jdbcTemplate.update("DELETE FROM roadmap_squad WHERE squad_id = ?::uuid", squadId);
            } else {
                jdbcTemplate.update("""
                        UPDATE roadmap_squad
                        SET owner_user_id = ?, updated_at = now()
                        WHERE squad_id = ?::uuid
                        """, replacements.getFirst(), squadId);
            }
        }
        jdbcTemplate.update("DELETE FROM roadmap_squad_member WHERE user_id = ?", normalized);
        jdbcTemplate.update("DELETE FROM platform_event WHERE user_id = ?", normalized);
        jdbcTemplate.update("DELETE FROM platform_crash_report WHERE user_id = ?", normalized);
        jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", normalized);
    }

    private AccountDeletionReceipt findDeletionReceipt(
            String subjectHash,
            boolean replayed
    ) {
        List<AccountDeletionReceipt> receipts = jdbcTemplate.query("""
                SELECT receipt_id, requested_at, completed_at
                FROM account_deletion_receipt
                WHERE subject_hash = ?
                """, (resultSet, rowNumber) -> new AccountDeletionReceipt(
                resultSet.getObject("receipt_id", UUID.class),
                "COMPLETED",
                resultSet.getTimestamp("requested_at").toInstant(),
                resultSet.getTimestamp("completed_at").toInstant(),
                replayed
        ), subjectHash);
        return receipts.isEmpty() ? null : receipts.getFirst();
    }

    public int cleanupActivityRetention() {
        return retentionService.cleanup();
    }

    private Map<String, Object> retentionAtDay(int day) {
        Long retained = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM app_user u
                WHERE EXISTS (
                    SELECT 1
                    FROM activity_sync_state a
                    WHERE a.user_id = u.user_id
                      AND a.local_date = (u.created_at AT TIME ZONE 'UTC')::date + ?
                ) OR EXISTS (
                    SELECT 1
                    FROM platform_event e
                    WHERE e.user_id = u.user_id
                      AND (e.occurred_at AT TIME ZONE 'UTC')::date =
                          (u.created_at AT TIME ZONE 'UTC')::date + ?
                )
                """, Long.class, day, day);
        long cohort = queryLong("SELECT count(*) FROM app_user");
        long retainedValue = retained == null ? 0 : retained;
        return Map.of(
                "day", day,
                "retainedUsers", retainedValue,
                "rate", cohort == 0 ? 0.0 : retainedValue * 1.0 / cohort
        );
    }

    private Map<String, Object> onboardingSummary() {
        Long started = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM roadmap_user_state
                WHERE jsonb_array_length(state_json -> 'completedOnboardingSteps') > 0
                """, Long.class);
        Long completed = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM roadmap_user_state
                WHERE state_json -> 'completedOnboardingSteps' @>
                      '["welcome","health-permission","first-sync","first-expedition"]'::jsonb
                """, Long.class);
        return Map.of(
                "startedUsers", started == null ? 0 : started,
                "completedUsers", completed == null ? 0 : completed
        );
    }

    private long queryLong(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value == null ? 0 : value;
    }

    private void validateRemoteConfig(Map<String, Object> config) {
        if (config == null || !config.keySet().containsAll(REQUIRED_CONFIG_KEYS)) {
            throw new PlatformValidationException(
                    "config должен содержать полный обязательный набор полей",
                    "config"
            );
        }
        requireBoolean(config, "backgroundHealthSyncEnabled");
        requireBoolean(config, "sandboxPaymentsEnabled");
        requireBoolean(config, "weeklyRouteEnabled");
        requireNumber(config, "activityRetentionDays", 1, 3650);
        requireNumber(config, "weeklyRouteEnergy", 10, 10_000);
        Object seasonId = config.get("seasonId");
        if (!(seasonId instanceof String value) || value.isBlank()) {
            throw new PlatformValidationException("seasonId обязателен", "config.seasonId");
        }
    }

    private void requireBoolean(Map<String, Object> config, String key) {
        if (!(config.get(key) instanceof Boolean)) {
            throw new PlatformValidationException(
                    key + " должен быть boolean",
                    "config." + key
            );
        }
    }

    private void requireNumber(Map<String, Object> config, String key, long min, long max) {
        if (!(config.get(key) instanceof Number number)
                || number.longValue() < min
                || number.longValue() > max) {
            throw new PlatformValidationException(
                    key + " вне допустимого диапазона",
                    "config." + key
            );
        }
    }

    private void ensureUser(String userId, Instant observedAt) {
        accountDeletionRegistry.requireActive(userId);
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, ?, ?)
                ON CONFLICT (user_id) DO UPDATE
                SET last_seen_at = GREATEST(app_user.last_seen_at, EXCLUDED.last_seen_at)
                """, requireText(userId, "userId"), timestamp, timestamp);
    }

    private void ensureDevice(String userId, String deviceId, Instant observedAt) {
        ensureUser(userId, observedAt);
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO app_device (user_id, device_id, created_at, last_seen_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (user_id, device_id) DO UPDATE
                SET last_seen_at = GREATEST(app_device.last_seen_at, EXCLUDED.last_seen_at)
                """,
                requireText(userId, "userId"),
                requireText(deviceId, "deviceId"),
                timestamp,
                timestamp
        );
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value == null ? Map.of() : value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Не удалось сериализовать JSON", exception);
        }
    }

    private Object readJson(String json) {
        if (json == null) {
            return null;
        }
        try {
            return objectMapper.readValue(json, Object.class);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Некорректный JSON", exception);
        }
    }

    private String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }

    private Instant now() {
        return Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
    }

    private String requireText(String value, String field) {
        if (!hasText(value)) {
            throw new PlatformValidationException("Поле обязательно", field);
        }
        return value.trim();
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private String normalizeNullable(String value) {
        return hasText(value) ? value.trim() : null;
    }
}
