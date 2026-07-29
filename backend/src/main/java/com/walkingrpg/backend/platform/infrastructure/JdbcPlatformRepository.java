package com.walkingrpg.backend.platform.infrastructure;

import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import tools.jackson.core.JacksonException;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.platform.application.PlatformStateConflictException;
import com.walkingrpg.backend.platform.domain.PlatformCommandScope;
import com.walkingrpg.backend.platform.domain.PlatformUserState;
import com.walkingrpg.backend.platform.domain.ProcessedPlatformCommand;
import com.walkingrpg.backend.platform.domain.SquadView;
import com.walkingrpg.backend.platform.payment.PaymentReceipt;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcPlatformRepository implements PlatformRepository {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };
    private static final String USER_LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 17))
            """;

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public JdbcPlatformRepository(
            JdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    @Override
    public void acquireUserLock(String userId) {
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(USER_LOCK_SQL)) {
                statement.setString(1, userId.length() + ":" + userId);
                statement.execute();
            }
            return null;
        });
    }

    @Override
    public Optional<PlatformUserState> findState(String userId) {
        List<PlatformUserState> states = jdbcTemplate.query("""
                SELECT state_json::text
                FROM roadmap_user_state
                WHERE user_id = ?
                """, (resultSet, rowNumber) -> readState(resultSet.getString(1)), userId);
        return states.stream().findFirst();
    }

    @Override
    public PlatformUserState lockOrCreateState(
            String userId,
            PlatformUserState initialState,
            Instant observedAt
    ) {
        ensureUser(userId, observedAt);
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO roadmap_user_state (
                    user_id, state_json, version, created_at, updated_at
                ) VALUES (?, ?::jsonb, ?, ?, ?)
                ON CONFLICT (user_id) DO NOTHING
                """,
                userId,
                writeJson(initialState),
                initialState.version(),
                timestamp,
                timestamp
        );
        List<PlatformUserState> states = jdbcTemplate.query("""
                SELECT state_json::text
                FROM roadmap_user_state
                WHERE user_id = ?
                FOR UPDATE
                """, (resultSet, rowNumber) -> readState(resultSet.getString(1)), userId);
        return states.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Platform state не создан"));
    }

    @Override
    public void saveState(String userId, PlatformUserState state, Instant updatedAt) {
        int updated = jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = ?::jsonb,
                    version = ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                writeJson(state),
                state.version(),
                Timestamp.from(updatedAt),
                userId
        );
        if (updated != 1) {
            throw new IllegalStateException("Не удалось сохранить platform state");
        }
    }

    @Override
    public Optional<ProcessedPlatformCommand> findProcessed(PlatformCommandScope scope) {
        List<ProcessedPlatformCommand> commands = jdbcTemplate.query("""
                SELECT request_fingerprint, response_json::text
                FROM processed_roadmap_command
                WHERE user_id = ?
                  AND command_type = ?
                  AND idempotency_key = ?
                """, (resultSet, rowNumber) -> new ProcessedPlatformCommand(
                resultSet.getString("request_fingerprint"),
                resultSet.getString("response_json")
        ), scope.userId(), scope.commandType(), scope.idempotencyKey());
        return commands.stream().findFirst();
    }

    @Override
    public void saveProcessed(
            PlatformCommandScope scope,
            ProcessedPlatformCommand processed,
            Instant createdAt
    ) {
        jdbcTemplate.update("""
                INSERT INTO processed_roadmap_command (
                    user_id, command_type, idempotency_key,
                    request_fingerprint, response_json, created_at
                ) VALUES (?, ?, ?, ?, ?::jsonb, ?)
                """,
                scope.userId(),
                scope.commandType(),
                scope.idempotencyKey(),
                processed.requestFingerprint(),
                processed.responseJson(),
                Timestamp.from(createdAt)
        );
    }

    @Override
    public String activeContentVersion() {
        List<String> versions = jdbcTemplate.query("""
                SELECT content_version
                FROM content_release
                WHERE is_active
                ORDER BY created_at DESC
                LIMIT 1
                """, (resultSet, rowNumber) -> resultSet.getString(1));
        return versions.stream().findFirst().orElse("chapter-1-v1");
    }

    @Override
    public Map<String, Object> activeRemoteConfig() {
        List<Map<String, Object>> configs = jdbcTemplate.query("""
                SELECT config_json::text
                FROM remote_config_snapshot
                WHERE is_active
                ORDER BY created_at DESC
                LIMIT 1
                """, (resultSet, rowNumber) -> readMap(resultSet.getString(1)));
        return configs.stream().findFirst().orElseGet(JdbcPlatformRepository::defaultConfig);
    }

    @Override
    public void createSquad(
            String squadId,
            String name,
            String ownerUserId,
            Instant createdAt
    ) {
        ensureUser(ownerUserId, createdAt);
        Timestamp timestamp = Timestamp.from(createdAt);
        try {
            jdbcTemplate.update("""
                    INSERT INTO roadmap_squad (
                        squad_id, squad_name, owner_user_id, created_at, updated_at
                    ) VALUES (?::uuid, ?, ?, ?, ?)
                    """, squadId, name, ownerUserId, timestamp, timestamp);
            jdbcTemplate.update("""
                    INSERT INTO roadmap_squad_member (
                        squad_id, user_id, joined_at
                    ) VALUES (?::uuid, ?, ?)
                    """, squadId, ownerUserId, timestamp);
        } catch (DataIntegrityViolationException exception) {
            throw new PlatformStateConflictException("Не удалось создать отряд", Map.of(
                    "reason", "DUPLICATE_OR_MEMBERSHIP_CONFLICT"
            ));
        }
    }

    @Override
    public void joinSquad(String squadId, String userId, Instant joinedAt) {
        ensureUser(userId, joinedAt);
        try {
            int inserted = jdbcTemplate.update("""
                    INSERT INTO roadmap_squad_member (
                        squad_id, user_id, joined_at
                    )
                    SELECT ?::uuid, ?, ?
                    WHERE EXISTS (
                        SELECT 1 FROM roadmap_squad WHERE squad_id = ?::uuid
                    )
                    """, squadId, userId, Timestamp.from(joinedAt), squadId);
            if (inserted != 1) {
                throw new PlatformStateConflictException("Отряд не найден");
            }
        } catch (DataIntegrityViolationException exception) {
            throw new PlatformStateConflictException("Пользователь уже состоит в отряде");
        }
    }

    @Override
    public void leaveSquad(String squadId, String userId) {
        jdbcTemplate.update("""
                DELETE FROM roadmap_squad_member
                WHERE squad_id = ?::uuid
                  AND user_id = ?
                """, squadId, userId);
        List<String> members = jdbcTemplate.query("""
                SELECT user_id
                FROM roadmap_squad_member
                WHERE squad_id = ?::uuid
                ORDER BY joined_at, user_id
                """, (resultSet, rowNumber) -> resultSet.getString(1), squadId);
        if (members.isEmpty()) {
            jdbcTemplate.update("DELETE FROM roadmap_squad WHERE squad_id = ?::uuid", squadId);
            return;
        }
        jdbcTemplate.update("""
                UPDATE roadmap_squad
                SET owner_user_id = CASE
                        WHEN owner_user_id = ? THEN ?
                        ELSE owner_user_id
                    END,
                    updated_at = now()
                WHERE squad_id = ?::uuid
                """, userId, members.getFirst(), squadId);
    }

    @Override
    public Optional<SquadView> findSquadForUser(String userId) {
        List<SquadHeader> headers = jdbcTemplate.query("""
                SELECT s.squad_id::text, s.squad_name, s.owner_user_id
                FROM roadmap_squad s
                JOIN roadmap_squad_member member ON member.squad_id = s.squad_id
                WHERE member.user_id = ?
                """, (resultSet, rowNumber) -> new SquadHeader(
                resultSet.getString(1),
                resultSet.getString(2),
                resultSet.getString(3)
        ), userId);
        if (headers.isEmpty()) {
            return Optional.empty();
        }
        SquadHeader header = headers.getFirst();
        List<String> members = jdbcTemplate.query("""
                SELECT user_id
                FROM roadmap_squad_member
                WHERE squad_id = ?::uuid
                ORDER BY joined_at, user_id
                """, (resultSet, rowNumber) -> resultSet.getString(1), header.squadId());
        return Optional.of(new SquadView(
                header.squadId(),
                header.name(),
                header.ownerUserId(),
                members
        ));
    }

    @Override
    public void savePaymentIntent(
            String userId,
            String productId,
            long amountMinor,
            String idempotencyKey,
            PaymentReceipt receipt,
            Instant createdAt
    ) {
        ensureUser(userId, createdAt);
        jdbcTemplate.update("""
                INSERT INTO payment_intent (
                    payment_intent_id, user_id, product_id, amount_minor,
                    provider, provider_reference, status, idempotency_key,
                    created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
                ON CONFLICT (user_id, idempotency_key) DO NOTHING
                """,
                userId,
                productId,
                amountMinor,
                receipt.provider(),
                receipt.reference(),
                receipt.status(),
                idempotencyKey,
                Timestamp.from(createdAt),
                Timestamp.from(receipt.processedAt())
        );
    }

    @Override
    public void recordEvent(
            String userId,
            String eventName,
            Instant occurredAt,
            Map<String, Object> attributes
    ) {
        ensureUser(userId, occurredAt);
        jdbcTemplate.update("""
                INSERT INTO platform_event (
                    user_id, event_name, occurred_at, attributes, received_at
                ) VALUES (?, ?, ?, ?::jsonb, ?)
                """,
                userId,
                eventName,
                Timestamp.from(occurredAt),
                writeJson(attributes == null ? Map.of() : attributes),
                Timestamp.from(occurredAt)
        );
    }

    private void ensureUser(String userId, Instant observedAt) {
        accountDeletionRegistry.requireActive(userId);
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, ?, ?)
                ON CONFLICT (user_id) DO UPDATE
                SET last_seen_at = GREATEST(app_user.last_seen_at, EXCLUDED.last_seen_at)
                """, userId, timestamp, timestamp);
    }

    private PlatformUserState readState(String json) {
        try {
            return objectMapper.readValue(json, PlatformUserState.class);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Некорректный roadmap_user_state JSON", exception);
        }
    }

    private Map<String, Object> readMap(String json) {
        try {
            return objectMapper.readValue(json, MAP_TYPE);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Некорректный JSON конфигурации", exception);
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JacksonException exception) {
            throw new IllegalStateException("Не удалось сериализовать JSON", exception);
        }
    }

    private static Map<String, Object> defaultConfig() {
        Map<String, Object> config = new LinkedHashMap<>();
        config.put("backgroundHealthSyncEnabled", false);
        config.put("activityRetentionDays", 30);
        config.put("seasonId", "season-1");
        config.put("weeklyRouteEnergy", 120);
        config.put("sandboxPaymentsEnabled", true);
        config.put("weeklyRouteEnabled", true);
        return Map.copyOf(config);
    }

    private record SquadHeader(String squadId, String name, String ownerUserId) {
    }
}
