package com.walkingrpg.backend.platform.application;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Map;

import tools.jackson.databind.json.JsonMapper;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.activity.retention.ActivityRetentionService;
import com.walkingrpg.backend.platform.infrastructure.PlatformPublicationTransactionLock;
import com.walkingrpg.backend.platform.infrastructure.SquadTransactionLock;
import com.walkingrpg.backend.platform.payment.SandboxPaymentProvider;
import com.walkingrpg.backend.platform.push.DisabledPushDeliveryProvider;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class PlatformAdminServiceTest {

    private static final Instant PRE_LOCK_TIME =
            Instant.parse("2026-08-05T23:59:30Z");
    private static final Instant POST_LOCK_TIME =
            Instant.parse("2026-08-06T00:00:30Z");

    @Test
    void shouldTimestampUserTelemetryAfterAccountLock() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        AccountDeletionRegistry deletionRegistry =
                mock(AccountDeletionRegistry.class);
        MutableClock clock = new MutableClock(PRE_LOCK_TIME);
        doAnswer(invocation -> {
            clock.set(POST_LOCK_TIME);
            return null;
        }).when(deletionRegistry).requireActive("telemetry-lock-user");
        PlatformAdminService service = new PlatformAdminService(
                jdbcTemplate,
                JsonMapper.builder().findAndAddModules().build(),
                new SandboxPaymentProvider(),
                new DisabledPushDeliveryProvider(),
                mock(ActivityRetentionService.class),
                deletionRegistry,
                mock(PlatformPublicationTransactionLock.class),
                mock(SquadTransactionLock.class),
                clock
        );

        service.recordEvent(
                "telemetry-lock-user",
                "retention_boundary",
                null,
                Map.of()
        );

        verify(jdbcTemplate).update(
                contains("INSERT INTO platform_event"),
                eq("telemetry-lock-user"),
                eq("retention_boundary"),
                eq(Timestamp.from(POST_LOCK_TIME)),
                eq("{}"),
                eq(Timestamp.from(POST_LOCK_TIME))
        );
    }

    private static final class MutableClock extends Clock {
        private Instant current;
        private final ZoneId zone;

        private MutableClock(Instant current) {
            this(current, ZoneOffset.UTC);
        }

        private MutableClock(Instant current, ZoneId zone) {
            this.current = current;
            this.zone = zone;
        }

        @Override
        public ZoneId getZone() {
            return zone;
        }

        @Override
        public synchronized Clock withZone(ZoneId requestedZone) {
            return zone.equals(requestedZone)
                    ? this
                    : new MutableClock(current, requestedZone);
        }

        @Override
        public synchronized Instant instant() {
            return current;
        }

        private synchronized void set(Instant value) {
            current = value;
        }
    }
}
