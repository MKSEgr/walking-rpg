package com.walkingrpg.backend.platform.push;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import org.springframework.stereotype.Component;

@Component
public class DevelopmentPushDeliveryProvider implements PushDeliveryProvider {

    @Override
    public PushDeliveryResult send(String userId, String title, String body) {
        String reference = UUID.nameUUIDFromBytes(
                (userId + ":" + title + ":" + body).getBytes(StandardCharsets.UTF_8)
        ).toString();
        return new PushDeliveryResult("DEVELOPMENT", true, reference);
    }
}
