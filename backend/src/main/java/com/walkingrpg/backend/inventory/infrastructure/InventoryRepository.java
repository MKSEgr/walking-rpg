package com.walkingrpg.backend.inventory.infrastructure;

import java.util.List;

import com.walkingrpg.backend.inventory.domain.InventoryReward;
import com.walkingrpg.backend.inventory.domain.InventoryStackSnapshot;

public interface InventoryRepository {

    InventoryStackSnapshot applyReward(InventoryReward reward);

    List<InventoryStackSnapshot> findAll(String userId);
}
