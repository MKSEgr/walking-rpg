package com.walkingrpg.backend.platform.config;

import java.util.LinkedHashMap;
import java.util.Map;

import com.walkingrpg.backend.platform.payment.DisabledPaymentProvider;
import com.walkingrpg.backend.platform.payment.PaymentProvider;
import com.walkingrpg.backend.platform.payment.SandboxPaymentProvider;
import com.walkingrpg.backend.platform.push.DevelopmentPushDeliveryProvider;
import com.walkingrpg.backend.platform.push.DisabledPushDeliveryProvider;
import com.walkingrpg.backend.platform.push.PushDeliveryProvider;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.core.env.MapPropertySource;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

class PlatformProviderConfigurationTest {

    @Test
    void shouldUseFailClosedProvidersByDefault() {
        try (AnnotationConfigApplicationContext context = context(null, null, null)) {
            assertInstanceOf(
                    DisabledPaymentProvider.class,
                    context.getBean(PaymentProvider.class)
            );
            assertInstanceOf(
                    DisabledPushDeliveryProvider.class,
                    context.getBean(PushDeliveryProvider.class)
            );
        }
    }

    @Test
    void shouldRegisterDevelopmentProvidersOnlyWithProfileAndExplicitMode() {
        try (AnnotationConfigApplicationContext local =
                     context("local", "sandbox", "development");
             AnnotationConfigApplicationContext test =
                     context("test", "sandbox", "development")) {
            assertInstanceOf(
                    SandboxPaymentProvider.class,
                    local.getBean(PaymentProvider.class)
            );
            assertInstanceOf(
                    DevelopmentPushDeliveryProvider.class,
                    local.getBean(PushDeliveryProvider.class)
            );
            assertInstanceOf(
                    SandboxPaymentProvider.class,
                    test.getBean(PaymentProvider.class)
            );
            assertInstanceOf(
                    DevelopmentPushDeliveryProvider.class,
                    test.getBean(PushDeliveryProvider.class)
            );
        }
    }

    @Test
    void shouldKeepDisabledProvidersWhenDevelopmentProfileDoesNotOptIn() {
        try (AnnotationConfigApplicationContext context =
                     context("local", "disabled", "disabled")) {
            assertInstanceOf(
                    DisabledPaymentProvider.class,
                    context.getBean(PaymentProvider.class)
            );
            assertInstanceOf(
                    DisabledPushDeliveryProvider.class,
                    context.getBean(PushDeliveryProvider.class)
            );
        }
    }

    @Test
    void propertyAloneMustNeverRegisterDevelopmentProvidersInProtectedProfiles() {
        try (AnnotationConfigApplicationContext prod =
                     context("prod", "sandbox", "development");
             AnnotationConfigApplicationContext stage =
                     context("stage", "sandbox", "development")) {
            assertEquals(0, prod.getBeansOfType(PaymentProvider.class).size());
            assertEquals(0, prod.getBeansOfType(PushDeliveryProvider.class).size());
            assertEquals(0, stage.getBeansOfType(PaymentProvider.class).size());
            assertEquals(0, stage.getBeansOfType(PushDeliveryProvider.class).size());
        }
    }

    @Test
    void shouldRegisterDisabledProvidersInProtectedProfiles() {
        try (AnnotationConfigApplicationContext prod =
                     context("prod", "disabled", "disabled");
             AnnotationConfigApplicationContext stage =
                     context("stage", "disabled", "disabled")) {
            assertInstanceOf(
                    DisabledPaymentProvider.class,
                    prod.getBean(PaymentProvider.class)
            );
            assertInstanceOf(
                    DisabledPushDeliveryProvider.class,
                    prod.getBean(PushDeliveryProvider.class)
            );
            assertInstanceOf(
                    DisabledPaymentProvider.class,
                    stage.getBean(PaymentProvider.class)
            );
            assertInstanceOf(
                    DisabledPushDeliveryProvider.class,
                    stage.getBean(PushDeliveryProvider.class)
            );
        }
    }

    private AnnotationConfigApplicationContext context(
            String profile,
            String payment,
            String push
    ) {
        AnnotationConfigApplicationContext context =
                new AnnotationConfigApplicationContext();
        if (profile != null) {
            context.getEnvironment().setActiveProfiles(profile);
        }
        Map<String, Object> values = new LinkedHashMap<>();
        if (payment != null) {
            values.put("walking-rpg.providers.payment", payment);
        }
        if (push != null) {
            values.put("walking-rpg.providers.push", push);
        }
        context.getEnvironment().getPropertySources().addFirst(
                new MapPropertySource("provider-test", values)
        );
        context.register(
                SandboxPaymentProvider.class,
                DisabledPaymentProvider.class,
                DevelopmentPushDeliveryProvider.class,
                DisabledPushDeliveryProvider.class
        );
        context.refresh();
        return context;
    }
}
