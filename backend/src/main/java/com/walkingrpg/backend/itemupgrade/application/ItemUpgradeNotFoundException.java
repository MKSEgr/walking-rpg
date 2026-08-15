package com.walkingrpg.backend.itemupgrade.application;

public class ItemUpgradeNotFoundException extends RuntimeException {

    private final String upgradeId;

    public ItemUpgradeNotFoundException(String upgradeId) {
        super("Item upgrade не найден: " + upgradeId);
        this.upgradeId = upgradeId;
    }

    public String upgradeId() {
        return upgradeId;
    }
}
