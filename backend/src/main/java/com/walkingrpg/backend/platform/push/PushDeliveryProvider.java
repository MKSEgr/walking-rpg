package com.walkingrpg.backend.platform.push;

public interface PushDeliveryProvider {

    boolean isAvailable();

    PushDeliveryResult send(String userId, String title, String body);
}
