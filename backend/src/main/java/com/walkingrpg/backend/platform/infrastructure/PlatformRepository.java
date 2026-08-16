package com.walkingrpg.backend.platform.infrastructure;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import com.walkingrpg.backend.platform.domain.PlatformCommandScope;
import com.walkingrpg.backend.platform.domain.PlatformUserState;
import com.walkingrpg.backend.platform.domain.ProcessedPlatformCommand;
import com.walkingrpg.backend.platform.domain.SquadView;
import com.walkingrpg.backend.platform.payment.PaymentReceipt;

public interface PlatformRepository {

    void acquireUserLock(String userId);

    void acquireSquadLock(String squadId);

    Optional<PlatformUserState> findState(String userId);

    default Set<String> findUnlockedSkills(String userId) {
        return findState(userId)
                .map(PlatformUserState::unlockedSkills)
                .orElseGet(Set::of);
    }

    PlatformUserState lockOrCreateState(
            String userId,
            PlatformUserState initialState,
            Instant observedAt
    );

    void saveState(String userId, PlatformUserState state, Instant updatedAt);

    Optional<ProcessedPlatformCommand> findProcessed(PlatformCommandScope scope);

    void saveProcessed(
            PlatformCommandScope scope,
            ProcessedPlatformCommand processed,
            Instant createdAt
    );

    String activeContentVersion();

    Map<String, Object> activeRemoteConfig();

    Map<String, String> findEquippedCosmetics(String userId);

    void equipCosmetic(
            String userId,
            String slot,
            String cosmeticId,
            Instant equippedAt
    );

    void createSquad(
            String squadId,
            String name,
            String ownerUserId,
            Instant createdAt
    );

    void joinSquad(String squadId, String userId, Instant joinedAt);

    void leaveSquad(String squadId, String userId);

    Optional<SquadView> findSquadForUser(String userId);

    void savePaymentIntent(
            String userId,
            String productId,
            long amountMinor,
            String idempotencyKey,
            PaymentReceipt receipt,
            Instant createdAt
    );

    void recordEvent(
            String userId,
            String eventName,
            Instant occurredAt,
            Map<String, Object> attributes
    );
}
