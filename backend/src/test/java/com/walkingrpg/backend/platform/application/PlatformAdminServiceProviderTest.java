package com.walkingrpg.backend.platform.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import tools.jackson.databind.json.JsonMapper;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.activity.retention.ActivityRetentionService;
import com.walkingrpg.backend.platform.payment.DisabledPaymentProvider;
import com.walkingrpg.backend.platform.payment.SandboxPaymentProvider;
import com.walkingrpg.backend.platform.push.DisabledPushDeliveryProvider;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class PlatformAdminServiceProviderTest {

    private static final Instant NOW = Instant.parse("2026-07-30T08:00:00Z");

    @Test
    void disabledPushShouldRejectBeforeCreatingAUserOrWritingAnEvent() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        AccountDeletionRegistry deletionRegistry = mock(AccountDeletionRegistry.class);
        DisabledPushDeliveryProvider pushProvider = new DisabledPushDeliveryProvider();
        PlatformAdminService service = service(
                jdbcTemplate,
                new SandboxPaymentProvider(),
                pushProvider,
                deletionRegistry
        );

        assertFalse(pushProvider.isAvailable());
        assertThrows(
                PlatformStateConflictException.class,
                () -> service.sendTestPush(
                        "provider-user",
                        "Проверка",
                        "Push не должен быть отправлен"
                )
        );
        verifyNoInteractions(jdbcTemplate, deletionRegistry);
    }

    @Test
    void disabledPaymentShouldRejectSandboxRemoteConfigBeforeAnyWrite() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        AccountDeletionRegistry deletionRegistry = mock(AccountDeletionRegistry.class);
        PlatformAdminService service = service(
                jdbcTemplate,
                new DisabledPaymentProvider(),
                new DisabledPushDeliveryProvider(),
                deletionRegistry
        );

        PlatformValidationException exception = assertThrows(
                PlatformValidationException.class,
                () -> service.updateRemoteConfig(
                        "admin",
                        "unsafe-sandbox-config",
                        remoteConfig(true)
                )
        );
        assertFalse(exception.getMessage().isBlank());
        verifyNoInteractions(jdbcTemplate, deletionRegistry);
    }

    @Test
    void availableSandboxProviderMayBeEnabledExplicitlyInDevelopment() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        PlatformAdminService service = service(
                jdbcTemplate,
                new SandboxPaymentProvider(),
                new DisabledPushDeliveryProvider(),
                mock(AccountDeletionRegistry.class)
        );

        assertDoesNotThrow(() -> service.updateRemoteConfig(
                "admin",
                "local-sandbox-config",
                remoteConfig(true)
        ));
    }

    @Test
    void unsupportedBackgroundSyncShouldBeRejectedBeforeAnyWrite() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        PlatformAdminService service = service(
                jdbcTemplate,
                new SandboxPaymentProvider(),
                new DisabledPushDeliveryProvider(),
                mock(AccountDeletionRegistry.class)
        );

        Map<String, Object> config = new LinkedHashMap<>(remoteConfig(false));
        config.put("backgroundHealthSyncEnabled", true);
        PlatformValidationException exception = assertThrows(
                PlatformValidationException.class,
                () -> service.updateRemoteConfig(
                        "admin",
                        "unsupported-background-config",
                        config
                )
        );

        assertFalse(exception.getMessage().isBlank());
        verifyNoInteractions(jdbcTemplate);
    }

    @Test
    void serverOwnedCompassEventsCannotEnterThroughPublicTelemetry() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        AccountDeletionRegistry deletionRegistry = mock(AccountDeletionRegistry.class);
        PlatformAdminService service = service(
                jdbcTemplate,
                new SandboxPaymentProvider(),
                new DisabledPushDeliveryProvider(),
                deletionRegistry
        );

        for (String eventName : List.of(
                "compass_recipe_impression",
                "compass_route_impression"
        )) {
            PlatformValidationException exception = assertThrows(
                    PlatformValidationException.class,
                    () -> service.recordEvent(
                            "telemetry-user",
                            eventName,
                            NOW.minusSeconds(3_600),
                            Map.of("status", "forged")
                    )
            );
            assertEquals("eventName", exception.field());
            assertFalse(exception.getMessage().isBlank());
        }

        verifyNoInteractions(jdbcTemplate, deletionRegistry);
    }

    private PlatformAdminService service(
            JdbcTemplate jdbcTemplate,
            com.walkingrpg.backend.platform.payment.PaymentProvider paymentProvider,
            com.walkingrpg.backend.platform.push.PushDeliveryProvider pushProvider,
            AccountDeletionRegistry deletionRegistry
    ) {
        return new PlatformAdminService(
                jdbcTemplate,
                JsonMapper.builder().findAndAddModules().build(),
                paymentProvider,
                pushProvider,
                mock(ActivityRetentionService.class),
                deletionRegistry,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
    }

    private Map<String, Object> remoteConfig(boolean sandboxPaymentsEnabled) {
        return Map.of(
                "backgroundHealthSyncEnabled", false,
                "activityRetentionDays", 30,
                "seasonId", "season-1",
                "weeklyRouteEnergy", 120,
                "sandboxPaymentsEnabled", sandboxPaymentsEnabled,
                "weeklyRouteEnabled", true
        );
    }
}
