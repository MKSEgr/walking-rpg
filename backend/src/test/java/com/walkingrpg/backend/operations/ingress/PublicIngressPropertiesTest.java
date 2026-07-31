package com.walkingrpg.backend.operations.ingress;

import java.time.Duration;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PublicIngressPropertiesTest {

    @Test
    void shouldAcceptSafeDefaults() {
        assertDoesNotThrow(new PublicIngressProperties()::validate);
    }

    @Test
    void shouldRejectUnboundedClientRegistry() {
        PublicIngressProperties properties = new PublicIngressProperties();
        properties.setMaxTrackedClients(0);

        assertThrows(IllegalArgumentException.class, properties::validate);
    }

    @Test
    void shouldRejectInvalidIdleTtl() {
        PublicIngressProperties properties = new PublicIngressProperties();
        properties.setClientIdleTtl(Duration.ZERO);

        assertThrows(IllegalArgumentException.class, properties::validate);
    }

    @Test
    void shouldRejectExcessiveConfiguredBodyLimit() {
        PublicIngressProperties properties = new PublicIngressProperties();
        properties.getCrash().setMaxBodyBytes(1_048_577);

        assertThrows(IllegalArgumentException.class, properties::validate);
    }
}
