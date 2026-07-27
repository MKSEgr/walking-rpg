package com.walkingrpg.backend.platform.push;

public interface PushDeliveryProvider {

    PushDeliveryResult send(String userId, String title, String body);
}
