package com.walkingrpg.backend.operations.ingress;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicLong;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PublicIngressRateLimiterTest {

    @Test
    void shouldRejectClientAfterBurstAndRefillDeterministically() {
        PublicIngressProperties properties = properties();
        properties.getTelemetry().setClientBurstCapacity(1);
        properties.getTelemetry().setClientRequestsPerMinute(60);
        AtomicLong clock = new AtomicLong();
        PublicIngressRateLimiter limiter =
                new PublicIngressRateLimiter(properties, clock::get);

        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "client-a")
                .allowed());
        PublicIngressRateLimiter.Decision rejected =
                limiter.acquire(PublicIngressEndpoint.TELEMETRY, "client-a");

        assertFalse(rejected.allowed());
        assertEquals(PublicIngressRateLimiter.Rejection.CLIENT, rejected.rejection());
        assertEquals(1, rejected.retryAfterSeconds());

        clock.addAndGet(Duration.ofSeconds(1).toNanos());

        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "client-a")
                .allowed());
    }

    @Test
    void shouldEnforceGlobalLimitAcrossClients() {
        PublicIngressProperties properties = properties();
        properties.getTelemetry().setGlobalBurstCapacity(2);
        properties.getTelemetry().setGlobalRequestsPerMinute(60);
        PublicIngressRateLimiter limiter =
                new PublicIngressRateLimiter(properties, () -> 0L);

        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "client-a")
                .allowed());
        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "client-b")
                .allowed());
        PublicIngressRateLimiter.Decision rejected =
                limiter.acquire(PublicIngressEndpoint.TELEMETRY, "client-c");

        assertFalse(rejected.allowed());
        assertEquals(PublicIngressRateLimiter.Rejection.GLOBAL, rejected.rejection());
    }

    @Test
    void shouldNotLetClientLimitedTrafficDrainGlobalBucket() {
        PublicIngressProperties properties = properties();
        properties.getTelemetry().setClientBurstCapacity(1);
        properties.getTelemetry().setGlobalBurstCapacity(2);
        PublicIngressRateLimiter limiter =
                new PublicIngressRateLimiter(properties, () -> 0L);

        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "abusive")
                .allowed());
        for (int attempt = 0; attempt < 10; attempt++) {
            assertEquals(
                    PublicIngressRateLimiter.Rejection.CLIENT,
                    limiter.acquire(PublicIngressEndpoint.TELEMETRY, "abusive")
                            .rejection()
            );
        }

        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "healthy")
                .allowed());
    }

    @Test
    void shouldUseSharedOverflowBucketWithoutGrowingRegistry() {
        PublicIngressProperties properties = properties();
        properties.setMaxTrackedClients(1);
        properties.getTelemetry().setClientBurstCapacity(1);
        PublicIngressRateLimiter limiter =
                new PublicIngressRateLimiter(properties, () -> 0L);

        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "tracked")
                .allowed());
        assertTrue(limiter.acquire(PublicIngressEndpoint.TELEMETRY, "overflow-a")
                .allowed());
        PublicIngressRateLimiter.Decision rejected =
                limiter.acquire(PublicIngressEndpoint.TELEMETRY, "overflow-b");

        assertFalse(rejected.allowed());
        assertEquals(PublicIngressRateLimiter.Rejection.CLIENT, rejected.rejection());
        assertEquals(1, limiter.trackedClientCount());
    }

    @Test
    void shouldEvictIdleClientBeforeUsingOverflowBucket() {
        PublicIngressProperties properties = properties();
        properties.setMaxTrackedClients(1);
        properties.setClientIdleTtl(Duration.ofSeconds(2));
        AtomicLong clock = new AtomicLong();
        PublicIngressRateLimiter limiter =
                new PublicIngressRateLimiter(properties, clock::get);

        assertTrue(limiter.acquire(PublicIngressEndpoint.CRASH, "old-client").allowed());
        clock.addAndGet(Duration.ofSeconds(3).toNanos());
        assertTrue(limiter.acquire(PublicIngressEndpoint.CRASH, "new-client").allowed());

        assertEquals(1, limiter.trackedClientCount());
    }

    private PublicIngressProperties properties() {
        PublicIngressProperties properties = new PublicIngressProperties();
        properties.getTelemetry().setClientBurstCapacity(20);
        properties.getTelemetry().setClientRequestsPerMinute(1_200);
        properties.getTelemetry().setGlobalBurstCapacity(100);
        properties.getTelemetry().setGlobalRequestsPerMinute(6_000);
        properties.getCrash().setClientBurstCapacity(20);
        properties.getCrash().setClientRequestsPerMinute(1_200);
        properties.getCrash().setGlobalBurstCapacity(100);
        properties.getCrash().setGlobalRequestsPerMinute(6_000);
        return properties;
    }
}
