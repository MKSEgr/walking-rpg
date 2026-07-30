package com.walkingrpg.backend.operations;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.boot.Banner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.SystemEnvironmentPropertySource;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.mock.env.MockPropertySource;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ProductionOperationsGuardTest {

    private static final String SAFE_JDBC_URL =
            "jdbc:postgresql://db.internal.example:5432/walking_rpg"
                    + "?sslmode=verify-full";
    private static final AtomicBoolean STARTUP_SENTINEL = new AtomicBoolean();

    @Test
    void shouldIgnoreOperationsConfigurationOutsideProtectedProfiles() {
        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(
                        new MockEnvironment()
                )
        );

        MockEnvironment local = new MockEnvironment()
                .withProperty("management.server.address", "0.0.0.0");
        local.setActiveProfiles("local");
        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(local)
        );
    }

    @Test
    void shouldAcceptCanonicalOperationsContractForActiveAndDefaultProfiles() {
        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(
                        safeEnvironment("prod")
                )
        );
        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(
                        safeEnvironment("stage")
                )
        );

        MockEnvironment defaultProd = safeEnvironment();
        defaultProd.withProperty("spring.profiles.default", "prod");
        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(defaultProd)
        );
    }

    @Test
    void shouldAllowEquivalentOrderingAndASeparateValidPort() {
        MockEnvironment environment = safeEnvironment("prod")
                .withProperty("server.port", "8443")
                .withProperty("management.server.port", "9001")
                .withProperty(
                        "management.endpoints.web.exposure.include",
                        "prometheus, health"
                )
                .withProperty(
                        "management.endpoint.health.group.readiness.include",
                        "db, readinessState"
                )
                .withProperty(
                        "management.endpoint.health.status.http-mapping.down",
                        "503"
                )
                .withProperty(
                        "management.endpoint.health.status."
                                + "http-mapping.out-of-service",
                        "503"
                )
                .withProperty(
                        "management.endpoint.health.status."
                                + "http-mapping.unknown",
                        "503"
                )
                .withProperty("management.server.address", "::1");

        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(environment)
        );
    }

    @Test
    void shouldAllowTighterPublicIngressLimits() {
        MockEnvironment environment = safeEnvironment("prod")
                .withProperty(
                        "walking-rpg.operations.public-ingress."
                                + "max-tracked-clients",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.client-idle-ttl",
                        "PT1S"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "max-body-bytes",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "client-requests-per-minute",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "client-burst-capacity",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "global-requests-per-minute",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "global-burst-capacity",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.crash."
                                + "max-body-bytes",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.crash."
                                + "client-requests-per-minute",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.crash."
                                + "client-burst-capacity",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.crash."
                                + "global-requests-per-minute",
                        "1"
                )
                .withProperty(
                        "walking-rpg.operations.public-ingress.crash."
                                + "global-burst-capacity",
                        "1"
                );

        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(environment)
        );
    }

    @ParameterizedTest(name = "{0}={1}")
    @MethodSource("unsafeOverrides")
    void shouldRejectUnsafeProtectedOverride(String name, String value) {
        MockEnvironment environment = safeEnvironment("prod")
                .withProperty(name, value);

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        environment
                )
        );

        assertTrue(
                exception.getMessage().contains(
                        expectedDiagnosticProperty(name)
                ),
                exception::getMessage
        );
    }

    @ParameterizedTest(name = "missing {0}")
    @MethodSource("publicIngressPropertyNames")
    void shouldRejectMissingPublicIngressProperty(String propertyName) {
        MockEnvironment environment = environmentWithout(propertyName, "prod");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        environment
                )
        );

        assertTrue(exception.getMessage().contains(propertyName));
    }

    @ParameterizedTest(name = "{0}=0")
    @MethodSource("publicIngressNumericPropertyNames")
    void shouldRejectNonPositivePublicIngressNumber(String propertyName) {
        MockEnvironment environment = safeEnvironment("prod")
                .withProperty(propertyName, "0");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        environment
                )
        );

        assertTrue(exception.getMessage().contains(propertyName));
    }

    @Test
    void shouldApplyGuardToRelaxedPropertyNames() {
        String canonicalName =
                "walking-rpg.operations.public-ingress.max-tracked-clients";
        MockEnvironment safeAlias = environmentWithout(canonicalName, "prod")
                .withProperty(
                        "walkingRpg.operations.publicIngress.maxTrackedClients",
                        "1"
                );

        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(safeAlias)
        );

        MockEnvironment unsafeAlias = environmentWithout(canonicalName, "prod")
                .withProperty(
                        "walkingRpg.operations.publicIngress.maxTrackedClients",
                        "10001"
                );

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        unsafeAlias
                )
        );

        assertTrue(exception.getMessage().contains(canonicalName));
    }

    @Test
    void shouldValidateIndexedManagementCollections() {
        String includeName =
                "management.endpoints.web.exposure.include";
        MockEnvironment safeIndexed = environmentWithout(includeName, "prod")
                .withProperty(includeName + "[0]", "health")
                .withProperty(includeName + "[1]", "prometheus");

        assertDoesNotThrow(() ->
                ProductionOperationsGuard.validateProtectedEnvironment(
                        safeIndexed
                )
        );

        String excludeName =
                "management.endpoints.web.exposure.exclude";
        MockEnvironment unsafeIndexed = safeEnvironment("prod")
                .withProperty(excludeName + "[0]", "health");
        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        unsafeIndexed
                )
        );

        assertTrue(exception.getMessage().contains(excludeName));
    }

    @Test
    void shouldPreferHigherPrecedenceIndexedManagementOverrides() {
        String exposureName =
                "management.endpoints.web.exposure.include";
        MockEnvironment exposure = safeEnvironment("prod");
        exposure.getPropertySources().addFirst(
                new MockPropertySource("indexedExposureOverride")
                        .withProperty(exposureName + "[0]", "env")
        );

        IllegalStateException exposureException = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        exposure
                )
        );
        assertTrue(exposureException.getMessage().contains(exposureName));

        String readinessName =
                "management.endpoint.health.group.readiness.include";
        MockEnvironment readiness = safeEnvironment("prod");
        readiness.getPropertySources().addFirst(
                new MockPropertySource("indexedReadinessOverride")
                        .withProperty(
                                readinessName + "[0]",
                                "readinessState"
                        )
                        .withProperty(readinessName + "[1]", "diskSpace")
        );

        IllegalStateException readinessException = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        readiness
                )
        );
        assertTrue(readinessException.getMessage().contains(readinessName));
    }

    @Test
    void shouldRejectUnknownHealthGroupBeforeContextCreation() {
        String propertyName =
                "management.endpoint.health.group.evil.additional-path";
        MockEnvironment environment = safeEnvironment("prod")
                .withProperty(propertyName, "server:/livez");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        environment
                )
        );

        assertTrue(exception.getMessage().contains(propertyName));

        MockEnvironment environmentAlias = safeEnvironment("prod");
        environmentAlias.getPropertySources().addFirst(
                new MockPropertySource("unknownGroupOverride")
                        .withProperty(
                                "MANAGEMENT_ENDPOINT_HEALTH_GROUP_EVIL_"
                                        + "ADDITIONAL_PATH",
                                "server:/livez"
                        )
        );
        assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        environmentAlias
                )
        );

        for (String ambiguous : new String[]{
                "management.endpoint.health.group.livenessinclude."
                        + "additional-path",
                "management.endpoint.health.group.readinessstatus."
                        + "http-mapping.down",
                "management.endpoint.health.group[evil].additional-path",
                "management.endpoint.health.group.readiness.roles",
                "management.endpoint.health.group.readiness.future-policy",
                "managementEndpointHealthGroupLivenessInclude"
        }) {
            MockEnvironment ambiguousGroup = safeEnvironment("prod")
                    .withProperty(ambiguous, "server:/livez");
            IllegalStateException ambiguousException = assertThrows(
                    IllegalStateException.class,
                    () -> ProductionOperationsGuard
                            .validateProtectedEnvironment(ambiguousGroup)
            );
            assertTrue(ambiguousException.getMessage().contains(ambiguous));
        }
    }

    @Test
    void shouldRejectBracketOverridesInsideAllowedHealthGroups() {
        for (String propertyName : new String[]{
                "management.endpoint.health.group[readiness].show-details",
                "management.endpoint.health.group[readiness].additional-path",
                "management.endpoint.health.group[readiness].include[0]",
                "management.endpoint.health.group.readiness.include[0]"
        }) {
            MockEnvironment environment = safeEnvironment("prod");
            environment.getPropertySources().addFirst(
                    new MockPropertySource("bracketHealthGroupOverride")
                            .withProperty(propertyName, "always")
            );

            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> ProductionOperationsGuard
                            .validateProtectedEnvironment(environment)
            );
            assertTrue(
                    exception.getMessage().contains(
                            expectedDiagnosticProperty(propertyName)
                    ),
                    exception::getMessage
            );
        }
    }

    @Test
    void shouldRejectBracketMapOverridesAndUnreviewedMetricTags() {
        MockEnvironment pathMapping = safeEnvironment("prod");
        pathMapping.getPropertySources().addFirst(
                new MockPropertySource("pathMappingOverride")
                        .withProperty(
                                "management.endpoints.web."
                                        + "path-mapping[health]",
                                "status"
                        )
        );
        IllegalStateException pathMappingException = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        pathMapping
                )
        );
        assertTrue(pathMappingException.getMessage().contains(
                "management.endpoints.web.path-mapping"
        ));

        MockEnvironment applicationTag = safeEnvironment("prod");
        applicationTag.getPropertySources().addFirst(
                new MockPropertySource("applicationTagOverride")
                        .withProperty(
                                "management.metrics.tags[application]",
                                "other"
                        )
        );
        IllegalStateException applicationTagException = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        applicationTag
                )
        );
        assertTrue(applicationTagException.getMessage().contains(
                "management.metrics.tags"
        ));

        MockEnvironment extraTag = safeEnvironment("prod")
                .withProperty("management.metrics.tags.secret", "token");
        assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        extraTag
                )
        );

        MockEnvironment observationTag = safeEnvironment("prod")
                .withProperty(
                        "management.observations.key-values.account",
                        "secret"
                );
        assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        observationTag
                )
        );

        for (String propertyName : new String[]{
                "management.metrics.enable[all]",
                "management.metrics.enable.walking.rpg.public.ingress",
                "management.observations.enable[http.server.requests]",
                "management.metrics.observations.ignored-meters[0]"
        }) {
            MockEnvironment enableFilter = safeEnvironment("prod");
            enableFilter.getPropertySources().addFirst(
                    new MockPropertySource("metricEnableOverride")
                            .withProperty(propertyName, "false")
            );
            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> ProductionOperationsGuard
                            .validateProtectedEnvironment(enableFilter)
            );
            assertTrue(exception.getMessage().contains(
                    propertyName.startsWith("management.metrics")
                            ? propertyName.startsWith(
                                    "management.metrics.observations"
                            )
                                    ? "management.metrics.observations"
                                    : "management.metrics.enable"
                            : "management.observations.enable"
            ));
        }

        MockEnvironment applicationName = safeEnvironment("prod")
                .withProperty("spring.application.name", "secret");
        assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        applicationName
                )
        );
    }

    @Test
    void shouldRejectLateServletContextPropertyOverrides() {
        for (String propertyName : new String[]{
                "server.servlet.context-parameters"
                        + "[management.endpoints.web.exposure.include]",
                "server.servlet.context-parameters"
                        + "[management.endpoint.health.group.evil.additional-path]"
        }) {
            MockEnvironment environment = safeEnvironment("prod");
            environment.getPropertySources().addFirst(
                    new MockPropertySource("servletContextOverride")
                            .withProperty(propertyName, "*")
            );

            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> ProductionOperationsGuard
                            .validateProtectedEnvironment(environment)
            );
            assertTrue(exception.getMessage().contains(
                    "server.servlet.context-parameters"
            ));
        }
    }

    @Test
    void shouldRejectAutoConfigurationExclusions() {
        for (String propertyName : new String[]{
                "spring.autoconfigure.exclude",
                "spring.autoconfigure.exclude[0]"
        }) {
            MockEnvironment environment = safeEnvironment("prod");
            environment.getPropertySources().addFirst(
                    new MockPropertySource("autoConfigurationExclusion")
                            .withProperty(
                                    propertyName,
                                    "org.springframework.boot.jdbc."
                                            + "autoconfigure.health."
                                            + "DataSourceHealthContributor"
                                            + "AutoConfiguration"
                            )
            );

            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> ProductionOperationsGuard
                            .validateProtectedEnvironment(environment)
            );
            assertTrue(exception.getMessage().contains(
                "spring.autoconfigure.exclude"
            ));
        }

        MockEnvironment environmentAlias = safeEnvironment("prod");
        environmentAlias.getPropertySources().addFirst(
                new SystemEnvironmentPropertySource(
                        "autoConfigurationExclusionEnvironment",
                        Map.of(
                                "SPRING_AUTOCONFIGURE_EXCLUDE",
                                "org.springframework.boot.jdbc.autoconfigure."
                                        + "health.DataSourceHealthContributor"
                                        + "AutoConfiguration"
                        )
                )
        );
        IllegalStateException aliasException = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard
                        .validateProtectedEnvironment(environmentAlias)
        );
        assertTrue(aliasException.getMessage().contains(
                "spring.autoconfigure.exclude"
        ));
    }

    @Test
    void shouldRejectIndexedSecurityDispatcherOverride() {
        String propertyName = "spring.security.filter.dispatcher-types";
        MockEnvironment environment = safeEnvironment("prod");
        environment.getPropertySources().addFirst(
                new MockPropertySource("securityDispatcherOverride")
                        .withProperty(propertyName + "[0]", "error")
        );

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard
                        .validateProtectedEnvironment(environment)
        );
        assertTrue(exception.getMessage().contains(propertyName));
    }

    @Test
    void shouldRejectMissingRequiredProtectedProperty() {
        MockEnvironment environment = environmentWithout(
                "spring.jdbc.template.query-timeout",
                "prod"
        );

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> ProductionOperationsGuard.validateProtectedEnvironment(
                        environment
                )
        );

        assertTrue(exception.getMessage().contains(
                "spring.jdbc.template.query-timeout"
        ));
    }

    @Test
    void shouldRejectUnsafeOperationsConfigThroughEnvironmentPostProcessor() {
        MockEnvironment environment = safeEnvironment("prod")
                .withProperty(
                        "spring.datasource.url",
                        "jdbc:postgresql://db.internal.example:5432/walking_rpg"
                                + "?sslmode=verify-full"
                )
                .withProperty(
                        "spring.datasource.username",
                        "walking_rpg_app"
                )
                .withProperty(
                        "spring.datasource.password",
                        "strong-production-secret"
                )
                .withProperty("spring.flyway.enabled", "true")
                .withProperty("management.server.address", "0.0.0.0");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> new ProductionEnvironmentPostProcessor()
                        .postProcessEnvironment(environment, null)
        );

        assertTrue(exception.getMessage().contains(
                "management.server.address"
        ));
    }

    @Test
    void shouldRejectUnsafeProtectedConfigBeforeContextRefresh() {
        STARTUP_SENTINEL.set(false);
        SpringApplication application =
                new SpringApplication(GuardLifecycleConfiguration.class);
        application.setBannerMode(Banner.Mode.OFF);
        application.setLogStartupInfo(false);
        application.setRegisterShutdownHook(false);
        application.setWebApplicationType(WebApplicationType.SERVLET);

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> application.run(
                        "--spring.profiles.active=prod",
                        "--spring.datasource.url=" + SAFE_JDBC_URL,
                        "--spring.datasource.username=walking_rpg_app",
                        "--spring.datasource.password=strong-production-secret",
                        "--spring.flyway.enabled=true",
                        "--management.endpoint.health.status.order="
                                + "up,unknown,out-of-service,down",
                        "--logging.level.root=OFF"
                )
        );

        assertFalse(STARTUP_SENTINEL.get());
        assertTrue(causeContains(
                exception,
                "management.endpoint.health.status.order"
        ));
    }

    private static Stream<Arguments> unsafeOverrides() {
        return Stream.of(
                Arguments.of("management.server.port", "8080"),
                Arguments.of("management.server.port", "0"),
                Arguments.of("management.server.address", "0.0.0.0"),
                Arguments.of("management.server.address", "localhost"),
                Arguments.of("management.server.ssl.enabled", "true"),
                Arguments.of("server.shutdown", "immediate"),
                Arguments.of("server.forward-headers-strategy", "framework"),
                Arguments.of(
                        "spring.boot.enableautoconfiguration",
                        "false"
                ),
                Arguments.of("spring.main.lazy-initialization", "true"),
                Arguments.of("spring.main.register-shutdown-hook", "false"),
                Arguments.of("spring.main.web-application-type", "none"),
                Arguments.of("server.servlet.context-path", "/application"),
                Arguments.of("spring.mvc.servlet.path", "/mvc"),
                Arguments.of(
                        "spring.mvc.pathmatch.matching-strategy",
                        "ant-path-matcher"
                ),
                Arguments.of(
                        "spring.security.filter.dispatcher-types",
                        "error"
                ),
                Arguments.of(
                        "spring.lifecycle.timeout-per-shutdown-phase",
                        "30s"
                ),
                Arguments.of("server.tomcat.connection-timeout", "-1"),
                Arguments.of("server.tomcat.keep-alive-timeout", "30s"),
                Arguments.of("server.tomcat.mbeanregistry.enabled", "true"),
                Arguments.of("server.tomcat.max-keep-alive-requests", "-1"),
                Arguments.of("server.tomcat.max-parameter-count", "1000"),
                Arguments.of("server.max-http-request-header-size", "1MB"),
                Arguments.of("server.tomcat.max-swallow-size", "-1"),
                Arguments.of(
                        "spring.datasource.hikari.connection-timeout",
                        "30000"
                ),
                Arguments.of(
                        "spring.datasource.hikari.validation-timeout",
                        "5000"
                ),
                Arguments.of(
                        "spring.datasource.hikari.register-mbeans",
                        "true"
                ),
                Arguments.of("spring.jdbc.template.query-timeout", "60s"),
                Arguments.of("spring.mvc.async.request-timeout", "-1"),
                Arguments.of("spring.transaction.default-timeout", "60s"),
                Arguments.of(
                        "walking-rpg.operations.public-ingress."
                                + "max-tracked-clients",
                        "10001"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress."
                                + "max-tracked-clients",
                        "-1"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.client-idle-ttl",
                        "PT10M1S"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.client-idle-ttl",
                        "PT0S"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.client-idle-ttl",
                        "-PT1S"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "max-body-bytes",
                        "16385"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "client-requests-per-minute",
                        "61"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "client-burst-capacity",
                        "21"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "global-requests-per-minute",
                        "6001"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.telemetry."
                                + "global-burst-capacity",
                        "1001"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.crash."
                                + "max-body-bytes",
                        "65537"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.crash."
                                + "client-requests-per-minute",
                        "7"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.crash."
                                + "client-burst-capacity",
                        "4"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.crash."
                                + "global-requests-per-minute",
                        "601"
                ),
                Arguments.of(
                        "walking-rpg.operations.public-ingress.crash."
                                + "global-burst-capacity",
                        "101"
                ),
                Arguments.of("spring.jmx.enabled", "true"),
                Arguments.of("spring.application.admin.enabled", "true"),
                Arguments.of(
                        "management.endpoints.jmx.exposure.include",
                        "health"
                ),
                Arguments.of(
                        "management.endpoints.jmx.exposure.exclude",
                        "*"
                ),
                Arguments.of(
                        "management.endpoints.access.default",
                        "unrestricted"
                ),
                Arguments.of(
                        "management.endpoints.access.max-permitted",
                        "unrestricted"
                ),
                Arguments.of(
                        "management.endpoints.web.discovery.enabled",
                        "true"
                ),
                Arguments.of(
                        "management.endpoints.web.exposure.include",
                        "health,prometheus,info"
                ),
                Arguments.of(
                        "management.endpoints.web.exposure.exclude",
                        "health"
                ),
                Arguments.of(
                        "management.server.base-path",
                        "/ops"
                ),
                Arguments.of(
                        "management.endpoints.web.base-path",
                        "/management"
                ),
                Arguments.of(
                        "management.endpoints.web.path-mapping.health",
                        "status"
                ),
                Arguments.of(
                        "management.endpoints.web.path-mapping.prometheus",
                        "metrics"
                ),
                Arguments.of(
                        "management.prometheus.metrics.export.enabled",
                        "false"
                ),
                Arguments.of(
                        "management.prometheus.metrics.export."
                                + "pushgateway.enabled",
                        "true"
                ),
                Arguments.of(
                        "management.prometheus.metrics.export."
                                + "pushgateway.grouping-key.environment",
                        "production"
                ),
                Arguments.of(
                        "management.endpoint.health.access",
                        "unrestricted"
                ),
                Arguments.of(
                        "management.endpoint.health.cache.time-to-live",
                        "1h"
                ),
                Arguments.of(
                        "management.endpoint.health.probes.enabled",
                        "false"
                ),
                Arguments.of(
                        "management.endpoint.health.probes.add-additional-paths",
                        "false"
                ),
                Arguments.of(
                        "management.endpoint.health.show-components",
                        "always"
                ),
                Arguments.of(
                        "management.endpoint.health.show-details",
                        "when-authorized"
                ),
                Arguments.of(
                        "management.endpoint.health."
                                + "validate-group-membership",
                        "false"
                ),
                Arguments.of(
                        "management.health.defaults.enabled",
                        "false"
                ),
                Arguments.of(
                        "management.health.livenessstate.enabled",
                        "false"
                ),
                Arguments.of(
                        "management.health.readinessstate.enabled",
                        "false"
                ),
                Arguments.of(
                        "management.health.db.enabled",
                        "false"
                ),
                Arguments.of(
                        "management.endpoint.health.group.liveness.include",
                        "livenessState,db"
                ),
                Arguments.of(
                        "management.endpoint.health.group.readiness.include",
                        "readinessState"
                ),
                Arguments.of(
                        "management.endpoint.health.group.liveness.exclude",
                        "livenessState"
                ),
                Arguments.of(
                        "management.endpoint.health.group.readiness.exclude",
                        "db"
                ),
                Arguments.of(
                        "management.endpoint.health.group.liveness."
                                + "additional-path",
                        "server:/alive"
                ),
                Arguments.of(
                        "management.endpoint.health.group.readiness."
                                + "additional-path",
                        "server:/ready"
                ),
                Arguments.of(
                        "management.endpoint.health.group.liveness."
                                + "show-components",
                        "always"
                ),
                Arguments.of(
                        "management.endpoint.health.group.liveness."
                                + "show-details",
                        "always"
                ),
                Arguments.of(
                        "management.endpoint.health.group.readiness."
                                + "show-components",
                        "always"
                ),
                Arguments.of(
                        "management.endpoint.health.group.readiness."
                                + "show-details",
                        "always"
                ),
                Arguments.of(
                        "management.endpoint.health.status.order",
                        "up,unknown,out-of-service,down"
                ),
                Arguments.of(
                        "management.endpoint.health.status.http-mapping.down",
                        "200"
                ),
                Arguments.of(
                        "management.endpoint.health.status.http-mapping.fatal",
                        "503"
                ),
                Arguments.of(
                        "management.endpoint.health.group.liveness."
                                + "status.order",
                        "up,unknown,out-of-service,down"
                ),
                Arguments.of(
                        "management.endpoint.health.group.readiness."
                                + "status.http-mapping.out-of-service",
                        "200"
                ),
                Arguments.of(
                        "management.endpoint.prometheus.access",
                        "unrestricted"
                ),
                Arguments.of(
                        "management.endpoint.prometheus.cache.time-to-live",
                        "1h"
                ),
                Arguments.of(
                        "management.metrics.tags.application",
                        "other-service"
                ),
                Arguments.of(
                        "management.observations.http.server.requests.name",
                        "renamed.requests"
                ),
                Arguments.of(
                        "management.metrics.web.server.max-uri-tags",
                        "101"
                )
        );
    }

    private static String expectedDiagnosticProperty(String propertyName) {
        String indexedReadinessProperty =
                "management.endpoint.health.group.readiness.include";
        if (propertyName.startsWith(indexedReadinessProperty + "[")) {
            return indexedReadinessProperty;
        }
        for (String mapPrefix : List.of(
                "management.endpoints.web.path-mapping",
                "management.prometheus.metrics.export.pushgateway",
                "management.endpoint.health.status.http-mapping",
                "management.metrics.tags"
        )) {
            if (propertyName.equals(mapPrefix)
                    || propertyName.startsWith(mapPrefix + ".")
                    || propertyName.startsWith(mapPrefix + "[")) {
                return mapPrefix;
            }
        }
        return propertyName;
    }

    private static Stream<String> publicIngressPropertyNames() {
        return Stream.of(
                "walking-rpg.operations.public-ingress.max-tracked-clients",
                "walking-rpg.operations.public-ingress.client-idle-ttl",
                "walking-rpg.operations.public-ingress.telemetry.max-body-bytes",
                "walking-rpg.operations.public-ingress.telemetry."
                        + "client-requests-per-minute",
                "walking-rpg.operations.public-ingress.telemetry."
                        + "client-burst-capacity",
                "walking-rpg.operations.public-ingress.telemetry."
                        + "global-requests-per-minute",
                "walking-rpg.operations.public-ingress.telemetry."
                        + "global-burst-capacity",
                "walking-rpg.operations.public-ingress.crash.max-body-bytes",
                "walking-rpg.operations.public-ingress.crash."
                        + "client-requests-per-minute",
                "walking-rpg.operations.public-ingress.crash."
                        + "client-burst-capacity",
                "walking-rpg.operations.public-ingress.crash."
                        + "global-requests-per-minute",
                "walking-rpg.operations.public-ingress.crash."
                        + "global-burst-capacity"
        );
    }

    private static Stream<String> publicIngressNumericPropertyNames() {
        return publicIngressPropertyNames()
                .filter(name -> !name.endsWith("client-idle-ttl"));
    }

    private MockEnvironment safeEnvironment(String... profiles) {
        MockEnvironment environment = environmentWithout(null, profiles);
        environment.setActiveProfiles(profiles);
        return environment;
    }

    private MockEnvironment environmentWithout(
            String excludedProperty,
            String... profiles
    ) {
        MockEnvironment environment = new MockEnvironment();
        safeProperties().forEach((name, value) -> {
            if (!name.equals(excludedProperty)) {
                environment.withProperty(name, value);
            }
        });
        environment.setActiveProfiles(profiles);
        return environment;
    }

    private Map<String, String> safeProperties() {
        Map<String, String> properties = new LinkedHashMap<>();
        properties.put("spring.application.name", "walking-rpg-backend");
        properties.put("spring.application.admin.enabled", "false");
        properties.put("spring.boot.enableautoconfiguration", "true");
        properties.put("spring.jmx.enabled", "false");
        properties.put("server.port", "8080");
        properties.put("management.server.port", "8081");
        properties.put("management.server.address", "127.0.0.1");
        properties.put("management.server.ssl.enabled", "false");
        properties.put("server.shutdown", "graceful");
        properties.put("server.forward-headers-strategy", "none");
        properties.put("spring.main.lazy-initialization", "false");
        properties.put("spring.main.register-shutdown-hook", "true");
        properties.put("spring.main.web-application-type", "servlet");
        properties.put("server.servlet.context-path", "/");
        properties.put("spring.mvc.servlet.path", "/");
        properties.put(
                "spring.mvc.pathmatch.matching-strategy",
                "path-pattern-parser"
        );
        properties.put(
                "spring.security.filter.dispatcher-types",
                "async,error,forward,include,request"
        );
        properties.put(
                "spring.lifecycle.timeout-per-shutdown-phase",
                "20s"
        );
        properties.put("server.tomcat.connection-timeout", "5s");
        properties.put("server.tomcat.keep-alive-timeout", "15s");
        properties.put("server.tomcat.mbeanregistry.enabled", "false");
        properties.put("server.tomcat.max-keep-alive-requests", "100");
        properties.put("server.tomcat.max-parameter-count", "100");
        properties.put("server.max-http-request-header-size", "16KB");
        properties.put("server.tomcat.max-swallow-size", "256KB");
        properties.put(
                "spring.datasource.hikari.connection-timeout",
                "5000"
        );
        properties.put(
                "spring.datasource.hikari.validation-timeout",
                "3000"
        );
        properties.put(
                "spring.datasource.hikari.register-mbeans",
                "false"
        );
        properties.put("spring.jdbc.template.query-timeout", "10s");
        properties.put("spring.mvc.async.request-timeout", "10s");
        properties.put("spring.transaction.default-timeout", "15s");
        properties.put(
                "walking-rpg.operations.public-ingress.max-tracked-clients",
                "10000"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.client-idle-ttl",
                "PT10M"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.telemetry.max-body-bytes",
                "16384"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.telemetry."
                        + "client-requests-per-minute",
                "60"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.telemetry."
                        + "client-burst-capacity",
                "20"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.telemetry."
                        + "global-requests-per-minute",
                "6000"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.telemetry."
                        + "global-burst-capacity",
                "1000"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.crash.max-body-bytes",
                "65536"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.crash."
                        + "client-requests-per-minute",
                "6"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.crash."
                        + "client-burst-capacity",
                "3"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.crash."
                        + "global-requests-per-minute",
                "600"
        );
        properties.put(
                "walking-rpg.operations.public-ingress.crash."
                        + "global-burst-capacity",
                "100"
        );
        properties.put("management.endpoints.access.default", "none");
        properties.put(
                "management.endpoints.access.max-permitted",
                "read-only"
        );
        properties.put(
                "management.endpoints.web.discovery.enabled",
                "false"
        );
        properties.put(
                "management.endpoints.web.exposure.include",
                "health,prometheus"
        );
        properties.put(
                "management.prometheus.metrics.export.enabled",
                "true"
        );
        properties.put(
                "management.prometheus.metrics.export.pushgateway.enabled",
                "false"
        );
        properties.put("management.endpoint.health.access", "read-only");
        properties.put(
                "management.endpoint.health.cache.time-to-live",
                "0ms"
        );
        properties.put(
                "management.endpoint.health.probes.enabled",
                "true"
        );
        properties.put(
                "management.endpoint.health.probes.add-additional-paths",
                "true"
        );
        properties.put(
                "management.endpoint.health.show-components",
                "never"
        );
        properties.put(
                "management.endpoint.health.show-details",
                "never"
        );
        properties.put(
                "management.endpoint.health.status.order",
                "down,out-of-service,unknown,up"
        );
        properties.put(
                "management.endpoint.health.status.http-mapping.down",
                "503"
        );
        properties.put(
                "management.endpoint.health.status."
                        + "http-mapping.out-of-service",
                "503"
        );
        properties.put(
                "management.endpoint.health.status.http-mapping.unknown",
                "503"
        );
        properties.put(
                "management.endpoint.health.group.liveness.include",
                "livenessState"
        );
        properties.put(
                "management.endpoint.health.group.readiness.include",
                "readinessState,db"
        );
        properties.put(
                "management.endpoint.prometheus.access",
                "read-only"
        );
        properties.put(
                "management.endpoint.prometheus.cache.time-to-live",
                "0ms"
        );
        properties.put(
                "management.metrics.tags.application",
                "walking-rpg-backend"
        );
        properties.put(
                "management.observations.http.server.requests.name",
                "http.server.requests"
        );
        properties.put(
                "management.metrics.web.server.max-uri-tags",
                "100"
        );
        return properties;
    }

    private boolean causeContains(Throwable failure, String fragment) {
        Throwable current = failure;
        while (current != null) {
            if (current.getMessage() != null
                    && current.getMessage().contains(fragment)) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    @Configuration(proxyBeanMethods = false)
    static class GuardLifecycleConfiguration {

        @Bean
        String startupSentinel() {
            STARTUP_SENTINEL.set(true);
            return "created";
        }
    }
}
