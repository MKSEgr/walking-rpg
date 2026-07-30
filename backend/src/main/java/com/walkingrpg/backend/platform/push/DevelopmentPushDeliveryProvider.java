package com.walkingrpg.backend.platform.push;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile({"local", "test"})
@ConditionalOnProperty(
        prefix = "walking-rpg.providers",
        name = "push",
        havingValue = "development"
)
public class DevelopmentPushDeliveryProvider implements PushDeliveryProvider {

    @Override
    public boolean isAvailable() {
        return true;
    }

    @Override
    public PushDeliveryResult send(String userId, String title, String body) {
        String reference = UUID.nameUUIDFromBytes(
                (userId + ":" + title + ":" + body).getBytes(StandardCharsets.UTF_8)
        ).toString();
        return new PushDeliveryResult("DEVELOPMENT", true, reference);
    }
}
