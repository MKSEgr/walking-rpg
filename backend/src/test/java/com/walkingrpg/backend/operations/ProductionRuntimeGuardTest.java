package com.walkingrpg.backend.operations;

import java.util.Arrays;

import com.walkingrpg.backend.platform.config.PlatformProviderProperties;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ProductionRuntimeGuardTest {

    private static final String SAFE_URL =
            "jdbc:postgresql://db.internal.example:5432/walking_rpg"
                    + "?sslmode=verify-full";

    @Test
    void shouldAllowDisabledDefaultsAndExplicitDevelopmentProviders() {
        assertDoesNotThrow(() -> runtimeGuard("disabled", "disabled").afterPropertiesSet());
        assertDoesNotThrow(() ->
                runtimeGuard("sandbox", "development", "local").afterPropertiesSet()
        );
        assertDoesNotThrow(() ->
                runtimeGuard("sandbox", "development", "test").afterPropertiesSet()
        );
        assertDoesNotThrow(() ->
                runtimeGuard("disabled", "disabled", "prod").afterPropertiesSet()
        );
        assertDoesNotThrow(() ->
                runtimeGuard("disabled", "disabled", "stage").afterPropertiesSet()
        );
    }

    @Test
    void shouldRejectDevelopmentProvidersOutsideLocalOrTest() {
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("sandbox", "disabled").afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("disabled", "development").afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("sandbox", "development", "prod")
                        .afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("sandbox", "development", "stage")
                        .afterPropertiesSet()
        );
    }

    @Test
    void shouldRejectUnknownProviderModesAndAmbiguousProfiles() {
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("stripe", "disabled", "local").afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("disabled", "fcm", "local").afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("DISABLED", "disabled", "prod")
                        .afterPropertiesSet()
        );

        IllegalStateException mixedProtected = assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("disabled", "disabled", "prod", "stage")
                        .afterPropertiesSet()
        );
        assertTrue(mixedProtected.getMessage().contains(
                "prod/stage нельзя совмещать друг с другом или с local/test"
        ));
        assertThrows(
                IllegalStateException.class,
                () -> runtimeGuard("disabled", "disabled", "stage", "test")
                        .afterPropertiesSet()
        );
    }

    @Test
    void shouldValidateSafeProtectedDatasourceBeforeContextCreation() {
        MockEnvironment prod = safeProtectedEnvironment("prod");
        MockEnvironment stage = safeProtectedEnvironment("stage");

        assertDoesNotThrow(() ->
                environmentGuard().postProcessEnvironment(prod, null)
        );
        assertDoesNotThrow(() ->
                environmentGuard().postProcessEnvironment(stage, null)
        );
        assertDoesNotThrow(() ->
                environmentGuard().postProcessEnvironment(new MockEnvironment(), null)
        );
    }

    @Test
    void shouldRejectLocalInsecureOrAlternativeProtectedDatasource() {
        assertRejected(environment("prod",
                "jdbc:postgresql://localhost:5432/walking_rpg?sslmode=verify-full",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                "jdbc:postgresql://db.internal.example:5432/walking_rpg",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("stage",
                SAFE_URL,
                "postgres",
                "strong-production-secret"));
        assertRejected(environment("stage",
                SAFE_URL,
                "walking_rpg_app",
                "walking_rpg_local"));

        MockEnvironment hikariOverride = safeProtectedEnvironment("prod")
                .withProperty(
                        "spring.datasource.hikari.jdbc-url",
                        "jdbc:h2:mem:bypass"
                );
        assertRejected(hikariOverride);

        MockEnvironment hikariCamelCaseOverride = safeProtectedEnvironment("prod")
                .withProperty(
                        "spring.datasource.hikari.jdbcUrl",
                        "jdbc:h2:mem:bypass"
                );
        assertRejected(hikariCamelCaseOverride);

        MockEnvironment hikariCredentialsProvider =
                safeProtectedEnvironment("prod")
                        .withProperty(
                                "spring.datasource.hikari.credentialsProviderClassName",
                                "example.UnsafeCredentialsProvider"
                        );
        assertRejected(hikariCredentialsProvider);

        MockEnvironment flywayOverride = safeProtectedEnvironment("prod")
                .withProperty("spring.flyway.url", SAFE_URL);
        assertRejected(flywayOverride);

        MockEnvironment flywayDriverOverride = safeProtectedEnvironment("prod")
                .withProperty(
                        "spring.flyway.driverClassName",
                        "org.h2.Driver"
                );
        assertRejected(flywayDriverOverride);

        MockEnvironment flywayJdbcProperties = safeProtectedEnvironment("prod")
                .withProperty(
                        "spring.flyway.jdbc-properties.sslmode",
                        "disable"
                );
        assertRejected(flywayJdbcProperties);

        MockEnvironment hikariTlsFactory = safeProtectedEnvironment("prod")
                .withProperty(
                        "spring.datasource.hikari.data-source-properties.sslfactory",
                        "example.TrustAllFactory"
                );
        assertRejected(hikariTlsFactory);

        MockEnvironment hikariDataSourcePropertiesGroup =
                safeProtectedEnvironment("prod")
                        .withProperty(
                                "spring.datasource.hikari.data-source-properties",
                                "sslfactory=example.TrustAllFactory"
                        );
        assertRejected(hikariDataSourcePropertiesGroup);

        MockEnvironment hikariHostnameVerifier = safeProtectedEnvironment("prod")
                .withProperty(
                        "SPRING_DATASOURCE_HIKARI_DATA_SOURCE_PROPERTIES_"
                                + "SSLHOSTNAMEVERIFIER",
                        "example.AllowEveryHostname"
                );
        assertRejected(hikariHostnameVerifier);

        MockEnvironment hikariExternalConfiguration = safeProtectedEnvironment("prod")
                .withProperty(
                        "hikaricp.configurationFile",
                        "/run/secrets/unsafe-hikari.properties"
                );
        assertRejected(hikariExternalConfiguration);
    }

    @Test
    void shouldRejectDuplicateMultiHostCredentialsAndCustomTlsBypasses() {
        assertRejected(environment("prod",
                " " + SAFE_URL,
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                SAFE_URL + " ",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                "jdbc:postgresql://db.internal.example:5432/walking_rpg"
                        + "?sslmode=verify-full&sslmode=disable",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                "jdbc:postgresql://db.internal.example:5432,"
                        + "localhost:5432/walking_rpg?sslmode=verify-full",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                "jdbc:postgresql://db.internal.example:5432/walking_rpg"
                        + "?sslmode=verify-full&user=postgres",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                "jdbc:postgresql://db.internal.example:5432/walking_rpg"
                        + "?sslmode=verify-full&sslhostnameverifier=example.Bypass",
                "walking_rpg_app",
                "strong-production-secret"));
        assertRejected(environment("prod",
                "jdbc:postgresql://user:secret@db.internal.example:5432/walking_rpg"
                        + "?sslmode=verify-full",
                "walking_rpg_app",
                "strong-production-secret"));
    }

    @Test
    void shouldRejectDriverAliasAndNonCanonicalTlsParameters() {
        for (String query : new String[]{
                "SSLMODE=verify-full",
                "%73slmode=verify-full",
                "sslmode=%76erify-full",
                "sslmode=VERIFY-FULL",
                "sslmode=verify-full&PGHOST=localhost",
                "sslmode=verify-full&PGPORT=5432",
                "sslmode=verify-full&PGDBNAME=postgres",
                "sslmode=verify-full&host=localhost",
                "sslmode=verify-full&service=production"
        }) {
            assertRejected(environment("prod",
                    "jdbc:postgresql://db.internal.example:5432/walking_rpg?"
                            + query,
                    "walking_rpg_app",
                    "strong-production-secret"));
        }
    }

    @Test
    void shouldRejectLegacyNumericLoopbackHostSpellings() {
        for (String host : new String[]{
                "2130706433",
                "0177.0.0.1",
                "0"
        }) {
            assertRejected(environment("prod",
                    "jdbc:postgresql://" + host
                            + ":5432/walking_rpg?sslmode=verify-full",
                    "walking_rpg_app",
                    "strong-production-secret"));
        }
    }

    @Test
    void shouldApplyProtectedGuardToDefaultProfile() {
        MockEnvironment safeDefault = defaultProtectedEnvironment("prod", SAFE_URL);
        assertDoesNotThrow(() ->
                environmentGuard().postProcessEnvironment(safeDefault, null)
        );

        assertRejected(defaultProtectedEnvironment(
                "stage",
                "jdbc:postgresql://localhost:5432/walking_rpg"
                        + "?sslmode=verify-full"
        ));

        MockEnvironment developmentProvider = defaultProtectedEnvironment(
                "prod",
                SAFE_URL
        ).withProperty("walking-rpg.providers.payment", "sandbox");
        assertRejected(developmentProvider);
    }

    @Test
    void shouldRejectMixedProtectedProfilesBeforeApplicationContextRefresh() {
        MockEnvironment both = safeProtectedEnvironment("prod");
        both.setActiveProfiles("prod", "stage");
        assertRejected(both);

        MockEnvironment mixed = safeProtectedEnvironment("stage");
        mixed.setActiveProfiles("stage", "local");
        assertRejected(mixed);
    }

    private ProductionRuntimeGuard runtimeGuard(
            String payment,
            String push,
            String... profiles
    ) {
        PlatformProviderProperties properties = new PlatformProviderProperties();
        properties.setPayment(payment);
        properties.setPush(push);
        MockEnvironment environment = new MockEnvironment()
                .withProperty("walking-rpg.providers.payment", payment)
                .withProperty("walking-rpg.providers.push", push);
        environment.setActiveProfiles(profiles);
        if (Arrays.stream(profiles).anyMatch(
                ProductionRuntimeGuard.PROTECTED_PROFILES::contains
        )) {
            environment
                    .withProperty("spring.datasource.url", SAFE_URL)
                    .withProperty(
                            "spring.datasource.username",
                            "walking_rpg_app"
                    )
                    .withProperty(
                            "spring.datasource.password",
                            "strong-production-secret"
                    )
                    .withProperty("spring.flyway.enabled", "true");
        }
        return new ProductionRuntimeGuard(properties, environment);
    }

    private ProductionEnvironmentPostProcessor environmentGuard() {
        return new ProductionEnvironmentPostProcessor();
    }

    private MockEnvironment safeProtectedEnvironment(String profile) {
        return environment(
                profile,
                SAFE_URL,
                "walking_rpg_app",
                "strong-production-secret"
        );
    }

    private MockEnvironment defaultProtectedEnvironment(String profile, String url) {
        return new MockEnvironment()
                .withProperty("spring.profiles.default", profile)
                .withProperty("spring.datasource.url", url)
                .withProperty("spring.datasource.username", "walking_rpg_app")
                .withProperty(
                        "spring.datasource.password",
                        "strong-production-secret"
                )
                .withProperty("spring.flyway.enabled", "true");
    }

    private MockEnvironment environment(
            String profile,
            String url,
            String username,
            String password
    ) {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("spring.datasource.url", url)
                .withProperty("spring.datasource.username", username)
                .withProperty("spring.datasource.password", password)
                .withProperty("spring.flyway.enabled", "true");
        environment.setActiveProfiles(profile);
        return environment;
    }

    private void assertRejected(MockEnvironment environment) {
        assertThrows(
                IllegalStateException.class,
                () -> environmentGuard().postProcessEnvironment(environment, null)
        );
    }
}
