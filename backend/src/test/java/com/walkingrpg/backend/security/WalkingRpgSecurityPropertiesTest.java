package com.walkingrpg.backend.security;

import java.time.Duration;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class WalkingRpgSecurityPropertiesTest {

    @Test
    void shouldFailClosedByDefault() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();

        assertEquals(WalkingRpgSecurityProperties.Mode.JWT, properties.getMode());
        assertFalse(properties.isDemoEndpointsEnabled());
        assertEquals("device_id", properties.getDeviceClaim());
        assertEquals(
                Duration.ofMinutes(5),
                properties.getAccountDeletionMaxAuthenticationAge()
        );
    }
}
