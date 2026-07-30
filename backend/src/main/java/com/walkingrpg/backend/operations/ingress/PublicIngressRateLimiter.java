package com.walkingrpg.backend.operations.ingress;

import java.time.Duration;
import java.util.EnumMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.function.LongSupplier;

final class PublicIngressRateLimiter {

    enum Rejection {
        NONE,
        CLIENT,
        GLOBAL
    }

    record Decision(boolean allowed, Rejection rejection, long retryAfterSeconds) {

        static Decision allowedDecision() {
            return new Decision(true, Rejection.NONE, 0);
        }

        static Decision rejected(Rejection rejection, long retryAfterSeconds) {
            return new Decision(false, rejection, Math.max(1, retryAfterSeconds));
        }
    }

    private final PublicIngressProperties properties;
    private final LongSupplier nanoTime;
    private final long idleTtlNanos;
    private final Map<PublicIngressEndpoint, TokenBucket> globalBuckets;
    private final LinkedHashMap<String, ClientState> clients =
            new LinkedHashMap<>(128, 0.75f, true);
    private final ClientState overflowClient;

    PublicIngressRateLimiter(PublicIngressProperties properties) {
        this(properties, System::nanoTime);
    }

    PublicIngressRateLimiter(
            PublicIngressProperties properties,
            LongSupplier nanoTime
    ) {
        this.properties = Objects.requireNonNull(properties);
        this.nanoTime = Objects.requireNonNull(nanoTime);
        properties.validate();
        idleTtlNanos = toNanos(properties.getClientIdleTtl());
        long now = nanoTime.getAsLong();
        globalBuckets = new EnumMap<>(PublicIngressEndpoint.class);
        for (PublicIngressEndpoint endpoint : PublicIngressEndpoint.values()) {
            PublicIngressProperties.Endpoint policy = endpoint.policy(properties);
            globalBuckets.put(
                    endpoint,
                    new TokenBucket(
                            policy.getGlobalBurstCapacity(),
                            policy.getGlobalRequestsPerMinute(),
                            now
                    )
            );
        }
        overflowClient = new ClientState(properties, now);
    }

    synchronized Decision acquire(
            PublicIngressEndpoint endpoint,
            String clientKey
    ) {
        Objects.requireNonNull(endpoint);
        Objects.requireNonNull(clientKey);
        long now = nanoTime.getAsLong();

        ClientState client = clientState(clientKey, now);
        client.lastSeenNanos = now;
        TokenBucket.Attempt local = client.bucket(endpoint).tryConsume(now);
        if (!local.allowed()) {
            return Decision.rejected(Rejection.CLIENT, local.retryAfterSeconds());
        }
        TokenBucket.Attempt global = globalBuckets.get(endpoint).tryConsume(now);
        if (!global.allowed()) {
            client.bucket(endpoint).refund();
            return Decision.rejected(Rejection.GLOBAL, global.retryAfterSeconds());
        }
        return Decision.allowedDecision();
    }

    synchronized int trackedClientCount() {
        return clients.size();
    }

    private ClientState clientState(String clientKey, long now) {
        ClientState existing = clients.get(clientKey);
        if (existing != null) {
            return existing;
        }
        evictIdle(now);
        if (clients.size() >= properties.getMaxTrackedClients()) {
            return overflowClient;
        }
        ClientState created = new ClientState(properties, now);
        clients.put(clientKey, created);
        return created;
    }

    private void evictIdle(long now) {
        Iterator<Map.Entry<String, ClientState>> iterator =
                clients.entrySet().iterator();
        while (iterator.hasNext()) {
            ClientState client = iterator.next().getValue();
            if (elapsed(now, client.lastSeenNanos) < idleTtlNanos) {
                break;
            }
            iterator.remove();
        }
    }

    private static long toNanos(Duration duration) {
        try {
            return duration.toNanos();
        } catch (ArithmeticException exception) {
            return Long.MAX_VALUE;
        }
    }

    private static long elapsed(long now, long previous) {
        long elapsed = now - previous;
        return elapsed < 0 ? Long.MAX_VALUE : elapsed;
    }

    private static final class ClientState {

        private final Map<PublicIngressEndpoint, TokenBucket> buckets =
                new EnumMap<>(PublicIngressEndpoint.class);
        private long lastSeenNanos;

        private ClientState(PublicIngressProperties properties, long now) {
            lastSeenNanos = now;
            for (PublicIngressEndpoint endpoint : PublicIngressEndpoint.values()) {
                PublicIngressProperties.Endpoint policy = endpoint.policy(properties);
                buckets.put(
                        endpoint,
                        new TokenBucket(
                                policy.getClientBurstCapacity(),
                                policy.getClientRequestsPerMinute(),
                                now
                        )
                );
            }
        }

        private TokenBucket bucket(PublicIngressEndpoint endpoint) {
            return buckets.get(endpoint);
        }
    }

    private static final class TokenBucket {

        private final double capacity;
        private final double tokensPerNanosecond;
        private double tokens;
        private long lastRefillNanos;

        private TokenBucket(int capacity, int requestsPerMinute, long now) {
            this.capacity = capacity;
            tokensPerNanosecond =
                    requestsPerMinute / (60.0 * 1_000_000_000.0);
            tokens = capacity;
            lastRefillNanos = now;
        }

        private Attempt tryConsume(long now) {
            refill(now);
            if (tokens >= 1.0) {
                tokens -= 1.0;
                return Attempt.allowedAttempt();
            }
            double missingTokens = 1.0 - tokens;
            long retryNanos = (long) Math.ceil(missingTokens / tokensPerNanosecond);
            long retrySeconds = Math.max(
                    1,
                    (long) Math.ceil(retryNanos / 1_000_000_000.0)
            );
            return Attempt.rejectedAttempt(retrySeconds);
        }

        private void refill(long now) {
            long elapsed = PublicIngressRateLimiter.elapsed(now, lastRefillNanos);
            if (elapsed == 0) {
                return;
            }
            tokens = Math.min(capacity, tokens + elapsed * tokensPerNanosecond);
            lastRefillNanos = now;
        }

        private void refund() {
            tokens = Math.min(capacity, tokens + 1.0);
        }

        private record Attempt(boolean allowed, long retryAfterSeconds) {

            private static Attempt allowedAttempt() {
                return new Attempt(true, 0);
            }

            private static Attempt rejectedAttempt(long retryAfterSeconds) {
                return new Attempt(false, retryAfterSeconds);
            }
        }
    }
}
