package com.walkingrpg.backend.itemupgrade.application;

public class ItemUpgradeStateConflictException extends RuntimeException {

    private final String upgradeId;
    private final String itemId;
    private final String reason;

    public ItemUpgradeStateConflictException(
            String upgradeId,
            String itemId,
            String reason
    ) {
        super("Item upgrade недоступен: " + reason);
        this.upgradeId = upgradeId;
        this.itemId = itemId;
        this.reason = reason;
    }

    public String upgradeId() {
        return upgradeId;
    }

    public String itemId() {
        return itemId;
    }

    public String reason() {
        return reason;
    }
}
