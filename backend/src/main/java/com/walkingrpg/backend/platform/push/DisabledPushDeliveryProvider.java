package com.walkingrpg.backend.platform.push;

import com.walkingrpg.backend.platform.application.PlatformStateConflictException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "walking-rpg.providers",
        name = "push",
        havingValue = "disabled",
        matchIfMissing = true
)
public class DisabledPushDeliveryProvider implements PushDeliveryProvider {

    @Override
    public boolean isAvailable() {
        return false;
    }

    @Override
    public PushDeliveryResult send(String userId, String title, String body) {
        throw new PlatformStateConflictException(
                "Push-отправка недоступна в текущей конфигурации"
        );
    }
}
