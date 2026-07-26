package com.walkingrpg.backend.inventory.application;

import java.time.Instant;
import java.util.List;

import com.walkingrpg.backend.inventory.domain.InventoryReward;
import com.walkingrpg.backend.inventory.domain.InventoryRewardDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryRewardResult;
import com.walkingrpg.backend.inventory.domain.InventoryStackSnapshot;
import com.walkingrpg.backend.inventory.infrastructure.InventoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InventoryService {

    static final String EVENT_REASON = "EVENT_MATERIAL_REWARD";
    static final String EVENT_SOURCE_TYPE = "EVENT_RESOLUTION";

    private final InventoryRepository repository;

    public InventoryService(InventoryRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public InventoryRewardResult rewardEventMaterial(
            String userId,
            InventoryRewardDefinition rewardDefinition,
            String sourceKey,
            Instant occurredAt
    ) {
        InventoryStackSnapshot stack = repository.applyReward(new InventoryReward(
                userId,
                rewardDefinition.item().itemId(),
                rewardDefinition.quantity(),
                EVENT_REASON,
                EVENT_SOURCE_TYPE,
                sourceKey,
                occurredAt
        ));
        return new InventoryRewardResult(
                rewardDefinition.item(),
                rewardDefinition.quantity(),
                stack.quantity(),
                stack.version()
        );
    }

    @Transactional(readOnly = true)
    public List<InventoryStackSnapshot> findAll(String userId) {
        return repository.findAll(userId);
    }
}
