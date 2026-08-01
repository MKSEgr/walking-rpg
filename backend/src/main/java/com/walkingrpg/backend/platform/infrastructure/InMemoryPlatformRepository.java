package com.walkingrpg.backend.platform.infrastructure;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import com.walkingrpg.backend.platform.application.PlatformStateConflictException;
import com.walkingrpg.backend.platform.domain.PlatformCommandScope;
import com.walkingrpg.backend.platform.domain.PlatformUserState;
import com.walkingrpg.backend.platform.domain.ProcessedPlatformCommand;
import com.walkingrpg.backend.platform.domain.SquadView;
import com.walkingrpg.backend.platform.payment.PaymentReceipt;

public class InMemoryPlatformRepository implements PlatformRepository {

    private final Map<String, PlatformUserState> states = new HashMap<>();
    private final Map<PlatformCommandScope, ProcessedPlatformCommand> processed = new HashMap<>();
    private final Map<String, MutableSquad> squads = new HashMap<>();
    private final Map<String, String> squadByUser = new HashMap<>();
    private final Map<String, PaymentReceipt> payments = new HashMap<>();
    private final List<Map<String, Object>> events = new ArrayList<>();
    private Map<String, Object> remoteConfig = defaultConfig();
    private String contentVersion = "chapter-1-v2";

    @Override
    public synchronized void acquireUserLock(String userId) {
        // synchronized repository methods serialize the in-memory test implementation.
    }

    @Override
    public synchronized Optional<PlatformUserState> findState(String userId) {
        return Optional.ofNullable(states.get(userId));
    }

    @Override
    public synchronized PlatformUserState lockOrCreateState(
            String userId,
            PlatformUserState initialState,
            Instant observedAt
    ) {
        return states.computeIfAbsent(userId, ignored -> initialState);
    }

    @Override
    public synchronized void saveState(
            String userId,
            PlatformUserState state,
            Instant updatedAt
    ) {
        states.put(userId, state);
    }

    @Override
    public synchronized Optional<ProcessedPlatformCommand> findProcessed(
            PlatformCommandScope scope
    ) {
        return Optional.ofNullable(processed.get(scope));
    }

    @Override
    public synchronized void saveProcessed(
            PlatformCommandScope scope,
            ProcessedPlatformCommand value,
            Instant createdAt
    ) {
        processed.put(scope, value);
    }

    @Override
    public synchronized String activeContentVersion() {
        return contentVersion;
    }

    @Override
    public synchronized Map<String, Object> activeRemoteConfig() {
        return Map.copyOf(remoteConfig);
    }

    @Override
    public synchronized void createSquad(
            String squadId,
            String name,
            String ownerUserId,
            Instant createdAt
    ) {
        if (squadByUser.containsKey(ownerUserId)) {
            throw new PlatformStateConflictException("Пользователь уже состоит в отряде");
        }
        MutableSquad squad = new MutableSquad(squadId, name, ownerUserId);
        squad.members.add(ownerUserId);
        squads.put(squadId, squad);
        squadByUser.put(ownerUserId, squadId);
    }

    @Override
    public synchronized void joinSquad(String squadId, String userId, Instant joinedAt) {
        if (squadByUser.containsKey(userId)) {
            throw new PlatformStateConflictException("Пользователь уже состоит в отряде");
        }
        MutableSquad squad = squads.get(squadId);
        if (squad == null) {
            throw new PlatformStateConflictException("Отряд не найден");
        }
        squad.members.add(userId);
        squadByUser.put(userId, squadId);
    }

    @Override
    public synchronized void leaveSquad(String squadId, String userId) {
        MutableSquad squad = squads.get(squadId);
        if (squad == null) {
            return;
        }
        squad.members.remove(userId);
        squadByUser.remove(userId);
        if (squad.members.isEmpty()) {
            squads.remove(squadId);
        } else if (squad.ownerUserId.equals(userId)) {
            squad.ownerUserId = squad.members.iterator().next();
        }
    }

    @Override
    public synchronized Optional<SquadView> findSquadForUser(String userId) {
        String squadId = squadByUser.get(userId);
        MutableSquad squad = squadId == null ? null : squads.get(squadId);
        return squad == null
                ? Optional.empty()
                : Optional.of(new SquadView(
                        squad.squadId,
                        squad.name,
                        squad.ownerUserId,
                        List.copyOf(squad.members)
                ));
    }

    @Override
    public synchronized void savePaymentIntent(
            String userId,
            String productId,
            long amountMinor,
            String idempotencyKey,
            PaymentReceipt receipt,
            Instant createdAt
    ) {
        payments.putIfAbsent(userId + ":" + idempotencyKey, receipt);
    }

    @Override
    public synchronized void recordEvent(
            String userId,
            String eventName,
            Instant occurredAt,
            Map<String, Object> attributes
    ) {
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("userId", userId);
        event.put("eventName", eventName);
        event.put("occurredAt", occurredAt);
        event.put("attributes", attributes == null ? Map.of() : Map.copyOf(attributes));
        events.add(event);
    }

    public synchronized int processedCommandCount() {
        return processed.size();
    }

    public synchronized int paymentCount() {
        return payments.size();
    }

    public synchronized int eventCount() {
        return events.size();
    }

    public synchronized void setRemoteConfig(Map<String, Object> value) {
        remoteConfig = new LinkedHashMap<>(value);
    }

    public synchronized void setContentVersion(String value) {
        contentVersion = value;
    }

    private static Map<String, Object> defaultConfig() {
        return Map.of(
                "backgroundHealthSyncEnabled", false,
                "activityRetentionDays", 30,
                "seasonId", "season-1",
                "weeklyRouteEnergy", 120,
                "sandboxPaymentsEnabled", false,
                "weeklyRouteEnabled", true
        );
    }

    private static final class MutableSquad {
        private final String squadId;
        private final String name;
        private String ownerUserId;
        private final Set<String> members = new LinkedHashSet<>();

        private MutableSquad(String squadId, String name, String ownerUserId) {
            this.squadId = squadId;
            this.name = name;
            this.ownerUserId = ownerUserId;
        }
    }
}
