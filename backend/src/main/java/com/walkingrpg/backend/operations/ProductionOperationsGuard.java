package com.walkingrpg.backend.operations;

import java.time.Duration;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.bind.PropertySourcesPlaceholdersResolver;
import org.springframework.boot.context.properties.source.ConfigurationPropertyName;
import org.springframework.boot.context.properties.source.ConfigurationPropertySource;
import org.springframework.boot.context.properties.source.ConfigurationPropertySources;
import org.springframework.boot.context.properties.source.IterableConfigurationPropertySource;
import org.springframework.boot.convert.DurationStyle;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.EnumerablePropertySource;
import org.springframework.core.env.Environment;
import org.springframework.core.env.PropertySource;
import org.springframework.util.unit.DataSize;

public final class ProductionOperationsGuard {

    private static final Set<String> PROTECTED_PROFILES = Set.of("prod", "stage");
    private static final Set<String> LOOPBACK_ADDRESSES = Set.of(
            "127.0.0.1",
            "::1",
            "0:0:0:0:0:0:0:1"
    );
    private static final String COMPACT_HEALTH_GROUP_PREFIX =
            "managementendpointhealthgroup";
    private static final ConfigurationPropertyName HEALTH_GROUP_PROPERTY_PREFIX =
            ConfigurationPropertyName.of(
                    "management.endpoint.health.group"
            );
    private static final Set<String> ALLOWED_HEALTH_GROUPS =
            Set.of("liveness", "readiness");
    private static final Set<String> ALLOWED_HEALTH_GROUP_SINGLE_PROPERTIES =
            Set.of(
                    "include",
                    "exclude",
                    "additional-path",
                    "show-components",
                    "show-details"
            );

    private ProductionOperationsGuard() {
    }

    static void validateProtectedEnvironment(Environment environment) {
        if (effectiveProfiles(environment).stream()
                .noneMatch(PROTECTED_PROFILES::contains)) {
            return;
        }

        int applicationPort = port(environment, "server.port", "8080");
        int managementPort = port(environment, "management.server.port", null);
        if (applicationPort == managementPort) {
            throw invalid(
                    "management.server.port обязан отличаться от server.port"
            );
        }
        requireOneOf(
                environment,
                "management.server.address",
                LOOPBACK_ADDRESSES
        );
        requireBoolean(
                environment,
                "management.server.ssl.enabled",
                false
        );

        requireExact(environment, "server.shutdown", "graceful");
        requireExact(environment, "server.forward-headers-strategy", "none");
        requireEmptyList(environment, "spring.autoconfigure.exclude");
        requireBoolean(
                environment,
                "spring.boot.enableautoconfiguration",
                true
        );
        requireBoolean(environment, "spring.main.lazy-initialization", false);
        requireBoolean(
                environment,
                "spring.main.register-shutdown-hook",
                true
        );
        requireExact(
                environment,
                "spring.main.web-application-type",
                "servlet"
        );
        requireExact(environment, "server.servlet.context-path", "/");
        requireExact(environment, "spring.mvc.servlet.path", "/");
        requireExact(
                environment,
                "spring.mvc.pathmatch.matching-strategy",
                "path-pattern-parser"
        );
        requireSet(
                environment,
                "spring.security.filter.dispatcher-types",
                Set.of("async", "error", "forward", "include", "request")
        );
        requireDuration(
                environment,
                "spring.lifecycle.timeout-per-shutdown-phase",
                Duration.ofSeconds(20)
        );
        requireDuration(
                environment,
                "server.tomcat.connection-timeout",
                Duration.ofSeconds(5)
        );
        requireDuration(
                environment,
                "server.tomcat.keep-alive-timeout",
                Duration.ofSeconds(15)
        );
        requireBoolean(
                environment,
                "server.tomcat.mbeanregistry.enabled",
                false
        );
        requireLong(
                environment,
                "server.tomcat.max-keep-alive-requests",
                100
        );
        requireLong(environment, "server.tomcat.max-parameter-count", 100);
        requireDataSize(
                environment,
                "server.max-http-request-header-size",
                DataSize.ofKilobytes(16)
        );
        requireDataSize(
                environment,
                "server.tomcat.max-swallow-size",
                DataSize.ofKilobytes(256)
        );
        requireExactMap(
                environment,
                "server.servlet.context-parameters",
                Map.of()
        );

        requireLong(
                environment,
                "spring.datasource.hikari.connection-timeout",
                5_000
        );
        requireLong(
                environment,
                "spring.datasource.hikari.validation-timeout",
                3_000
        );
        requireBoolean(
                environment,
                "spring.datasource.hikari.register-mbeans",
                false
        );
        requireDuration(
                environment,
                "spring.jdbc.template.query-timeout",
                Duration.ofSeconds(10)
        );
        requireDuration(
                environment,
                "spring.mvc.async.request-timeout",
                Duration.ofSeconds(10)
        );
        requireDuration(
                environment,
                "spring.transaction.default-timeout",
                Duration.ofSeconds(15)
        );

        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.max-tracked-clients",
                10_000
        );
        requirePositiveDurationAtMost(
                environment,
                "walking-rpg.operations.public-ingress.client-idle-ttl",
                Duration.ofMinutes(10)
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.telemetry.max-body-bytes",
                16_384
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.telemetry."
                        + "client-requests-per-minute",
                60
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.telemetry."
                        + "client-burst-capacity",
                20
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.telemetry."
                        + "global-requests-per-minute",
                6_000
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.telemetry."
                        + "global-burst-capacity",
                1_000
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.crash.max-body-bytes",
                65_536
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.crash."
                        + "client-requests-per-minute",
                6
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.crash."
                        + "client-burst-capacity",
                3
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.crash."
                        + "global-requests-per-minute",
                600
        );
        requirePositiveLongAtMost(
                environment,
                "walking-rpg.operations.public-ingress.crash."
                        + "global-burst-capacity",
                100
        );

        requireBoolean(environment, "spring.jmx.enabled", false);
        requireBoolean(
                environment,
                "spring.application.admin.enabled",
                false
        );
        requireEmptyList(
                environment,
                "management.endpoints.jmx.exposure.include"
        );
        requireEmptyList(
                environment,
                "management.endpoints.jmx.exposure.exclude"
        );
        requireExact(environment, "management.endpoints.access.default", "none");
        requireExact(
                environment,
                "management.endpoints.access.max-permitted",
                "read-only"
        );
        requireBoolean(
                environment,
                "management.endpoints.web.discovery.enabled",
                false
        );
        requireSet(
                environment,
                "management.endpoints.web.exposure.include",
                Set.of("health", "prometheus")
        );
        requireEmptyList(
                environment,
                "management.endpoints.web.exposure.exclude"
        );
        requireExact(
                environment,
                "management.server.base-path",
                "/",
                "/"
        );
        requireExact(
                environment,
                "management.endpoints.web.base-path",
                "/actuator",
                "/actuator"
        );
        requireCanonicalWebPathMappings(environment);
        requireBoolean(
                environment,
                "management.prometheus.metrics.export.enabled",
                true
        );
        requireExactMap(
                environment,
                "management.prometheus.metrics.export.pushgateway",
                Map.of("enabled", "false")
        );
        requireExact(
                environment,
                "management.endpoint.health.access",
                "read-only"
        );
        requireDuration(
                environment,
                "management.endpoint.health.cache.time-to-live",
                Duration.ZERO
        );
        requireBoolean(
                environment,
                "management.endpoint.health.probes.enabled",
                true
        );
        requireBoolean(
                environment,
                "management.endpoint.health.probes.add-additional-paths",
                true
        );
        requireExact(
                environment,
                "management.endpoint.health.show-components",
                "never"
        );
        requireExact(
                environment,
                "management.endpoint.health.show-details",
                "never"
        );
        requireBoolean(
                environment,
                "management.endpoint.health.validate-group-membership",
                true,
                "true"
        );
        requireBoolean(
                environment,
                "management.health.defaults.enabled",
                true,
                "true"
        );
        requireBoolean(
                environment,
                "management.health.livenessstate.enabled",
                true,
                "true"
        );
        requireBoolean(
                environment,
                "management.health.readinessstate.enabled",
                true,
                "true"
        );
        requireBoolean(
                environment,
                "management.health.db.enabled",
                true,
                "true"
        );
        requireSet(
                environment,
                "management.endpoint.health.group.liveness.include",
                Set.of("livenessState")
        );
        requireSet(
                environment,
                "management.endpoint.health.group.readiness.include",
                Set.of("readinessState", "db")
        );
        rejectUnknownHealthGroupProperties(environment);
        requireHealthGroupPolicy(environment, "liveness");
        requireHealthGroupPolicy(environment, "readiness");
        requireHealthStatusPolicy(
                environment,
                "management.endpoint.health.status"
        );
        requireExact(
                environment,
                "management.endpoint.prometheus.access",
                "read-only"
        );
        requireDuration(
                environment,
                "management.endpoint.prometheus.cache.time-to-live",
                Duration.ZERO
        );

        requireExact(
                environment,
                "spring.application.name",
                "walking-rpg-backend"
        );
        requireExactMap(
                environment,
                "management.metrics.tags",
                Map.of("application", "walking-rpg-backend")
        );
        requireExactMap(
                environment,
                "management.observations.key-values",
                Map.of()
        );
        requireExact(
                environment,
                "management.observations.http.server.requests.name",
                "http.server.requests"
        );
        requireExactMap(
                environment,
                "management.metrics.enable",
                Map.of()
        );
        requireExactMap(
                environment,
                "management.observations.enable",
                Map.of()
        );
        requireEmptyList(
                environment,
                "management.metrics.observations.ignored-meters"
        );
        requireLong(
                environment,
                "management.metrics.web.server.max-uri-tags",
                100
        );
    }

    private static void requireHealthGroupPolicy(
            Environment environment,
            String group
    ) {
        String prefix = "management.endpoint.health.group." + group;
        requireEmptyList(environment, prefix + ".exclude");
        requireEmpty(environment, prefix + ".additional-path");
        requireExact(
                environment,
                prefix + ".show-components",
                "never",
                "never"
        );
        requireExact(
                environment,
                prefix + ".show-details",
                "never",
                "never"
        );
        requireEmptyList(environment, prefix + ".status.order");
        requireExactMap(
                environment,
                prefix + ".status.http-mapping",
                Map.of()
        );
    }

    private static void rejectUnknownHealthGroupProperties(
            Environment environment
    ) {
        if (!(environment instanceof ConfigurableEnvironment configurable)) {
            throw invalid(
                    "protected Environment обязан позволять перечислить "
                            + "health group properties"
            );
        }
        Set<String> unknown = new TreeSet<>();
        for (ConfigurationPropertySource source
                : ConfigurationPropertySources.from(
                        configurable.getPropertySources()
                )) {
            if (!(source instanceof IterableConfigurationPropertySource iterable)) {
                continue;
            }
            for (ConfigurationPropertyName name : iterable) {
                if (!HEALTH_GROUP_PROPERTY_PREFIX.isAncestorOf(name)) {
                    continue;
                }
                if (!isAllowedHealthGroupProperty(name)) {
                    unknown.add(name.toString());
                }
            }
        }
        for (PropertySource<?> source : configurable.getPropertySources()) {
            if (!(source instanceof EnumerablePropertySource<?> enumerable)) {
                continue;
            }
            for (String name : enumerable.getPropertyNames()) {
                String compact = compactPropertyName(name);
                if (!compact.startsWith(COMPACT_HEALTH_GROUP_PREFIX)) {
                    continue;
                }
                if (name.indexOf('[') >= 0 || name.indexOf(']') >= 0) {
                    unknown.add(name);
                    continue;
                }
                ConfigurationPropertyName adapted =
                        healthGroupPropertyNameFromRaw(name);
                if (adapted == null
                        || !isAllowedHealthGroupProperty(adapted)) {
                    unknown.add(name);
                }
            }
        }
        if (!unknown.isEmpty()) {
            throw invalid(
                    "разрешены только liveness/readiness health groups: "
                            + String.join(", ", unknown)
            );
        }
    }

    private static boolean isAllowedHealthGroupProperty(
            ConfigurationPropertyName name
    ) {
        int groupIndex = HEALTH_GROUP_PROPERTY_PREFIX.getNumberOfElements();
        if (!HEALTH_GROUP_PROPERTY_PREFIX.isAncestorOf(name)
                || name.getNumberOfElements() <= groupIndex + 1
                || !ALLOWED_HEALTH_GROUPS.contains(
                        name.getElement(
                                groupIndex,
                                ConfigurationPropertyName.Form.UNIFORM
                        )
                )) {
            return false;
        }
        int suffixElements = name.getNumberOfElements() - groupIndex - 1;
        String first = name.getElement(
                groupIndex + 1,
                ConfigurationPropertyName.Form.UNIFORM
        );
        if (suffixElements == 1) {
            return ALLOWED_HEALTH_GROUP_SINGLE_PROPERTIES.contains(first);
        }
        if (!"status".equals(first) || suffixElements < 2) {
            return false;
        }
        String second = name.getElement(
                groupIndex + 2,
                ConfigurationPropertyName.Form.UNIFORM
        );
        if (suffixElements == 2) {
            return "order".equals(second);
        }
        return suffixElements == 3 && "http-mapping".equals(second);
    }

    private static ConfigurationPropertyName healthGroupPropertyNameFromRaw(
            String name
    ) {
        char separator;
        if (name.indexOf('.') >= 0) {
            separator = '.';
        } else if (name.indexOf('_') >= 0) {
            separator = '_';
        } else {
            return null;
        }
        ConfigurationPropertyName adapted;
        try {
            adapted = ConfigurationPropertyName.adapt(name, separator);
        } catch (RuntimeException exception) {
            return null;
        }
        if (!HEALTH_GROUP_PROPERTY_PREFIX.isAncestorOf(adapted)) {
            return null;
        }
        return adapted;
    }

    private static void requireCanonicalWebPathMappings(
            Environment environment
    ) {
        String name = "management.endpoints.web.path-mapping";
        Map<String, String> mappings = stringMap(environment, name);
        Map<String, String> canonical = Map.of(
                "health", "health",
                "prometheus", "prometheus"
        );
        if (mappings.entrySet().stream().anyMatch(entry ->
                !canonical.containsKey(entry.getKey())
                        || !canonical.get(entry.getKey())
                                .equals(entry.getValue()))) {
            throw invalid(
                    name + " может содержать только канонические "
                            + "health=health и prometheus=prometheus"
            );
        }
    }

    private static void requireHealthStatusPolicy(
            Environment environment,
            String prefix
    ) {
        requireOrderedList(
                environment,
                prefix + ".order",
                List.of("down", "out-of-service", "unknown", "up"),
                null
        );

        String mappingName = prefix + ".http-mapping";
        Map<String, String> mappings = stringMap(environment, mappingName);
        if (!Map.of(
                "down", "503",
                "out-of-service", "503",
                "unknown", "503"
        ).equals(mappings)) {
            throw invalid(
                    mappingName + " обязан содержать ровно down=503, "
                            + "out-of-service=503 и unknown=503"
            );
        }
    }

    private static Set<String> effectiveProfiles(Environment environment) {
        String[] active = environment.getActiveProfiles();
        String[] profiles = active.length == 0
                ? environment.getDefaultProfiles()
                : active;
        return Arrays.stream(profiles)
                .map(value -> value.trim().toLowerCase(Locale.ROOT))
                .filter(value -> !value.isEmpty())
                .collect(Collectors.toUnmodifiableSet());
    }

    private static int port(
            Environment environment,
            String name,
            String defaultValue
    ) {
        long value = longValue(property(environment, name, defaultValue), name);
        if (value < 1 || value > 65_535) {
            throw invalid(name + " должен быть в диапазоне 1..65535");
        }
        return (int) value;
    }

    private static void requireDuration(
            Environment environment,
            String name,
            Duration expected
    ) {
        String value = required(environment, name);
        Duration actual;
        try {
            actual = DurationStyle.detectAndParse(value);
        } catch (RuntimeException exception) {
            throw invalid(name + " содержит некорректную duration");
        }
        if (!expected.equals(actual)) {
            throw invalid(name + " обязан быть равен " + expected);
        }
    }

    private static void requireDataSize(
            Environment environment,
            String name,
            DataSize expected
    ) {
        String value = required(environment, name);
        DataSize actual;
        try {
            actual = DataSize.parse(value);
        } catch (RuntimeException exception) {
            throw invalid(name + " содержит некорректный data size");
        }
        if (!expected.equals(actual)) {
            throw invalid(name + " обязан быть равен " + expected);
        }
    }

    private static void requirePositiveDurationAtMost(
            Environment environment,
            String name,
            Duration maximum
    ) {
        String value = required(environment, name);
        Duration actual;
        try {
            actual = DurationStyle.detectAndParse(value);
        } catch (RuntimeException exception) {
            throw invalid(name + " содержит некорректную duration");
        }
        if (actual.isZero()
                || actual.isNegative()
                || actual.compareTo(maximum) > 0) {
            throw invalid(
                    name + " должен быть положительным и не превышать "
                            + maximum
            );
        }
    }

    private static void requireLong(
            Environment environment,
            String name,
            long expected
    ) {
        long actual = longValue(required(environment, name), name);
        if (actual != expected) {
            throw invalid(name + " обязан быть равен " + expected);
        }
    }

    private static void requirePositiveLongAtMost(
            Environment environment,
            String name,
            long maximum
    ) {
        long actual = longValue(required(environment, name), name);
        if (actual <= 0 || actual > maximum) {
            throw invalid(
                    name + " должен быть в диапазоне 1.." + maximum
            );
        }
    }

    private static long longValue(String value, String name) {
        try {
            return Long.parseLong(value);
        } catch (NumberFormatException exception) {
            throw invalid(name + " обязан быть целым числом");
        }
    }

    private static void requireBoolean(
            Environment environment,
            String name,
            boolean expected
    ) {
        requireBoolean(environment, name, expected, null);
    }

    private static void requireBoolean(
            Environment environment,
            String name,
            boolean expected,
            String defaultValue
    ) {
        String value = property(environment, name, defaultValue);
        if (!Boolean.toString(expected).equals(value)) {
            throw invalid(name + " обязан быть равен " + expected);
        }
    }

    private static void requireEmpty(
            Environment environment,
            String name
    ) {
        String value = property(environment, name, "");
        if (!value.isEmpty()) {
            throw invalid(name + " обязан быть пустым");
        }
    }

    private static void requireOrderedList(
            Environment environment,
            String name,
            List<String> expected,
            String defaultValue
    ) {
        List<String> fallback = defaultValue == null
                ? null
                : Arrays.stream(defaultValue.split(",", -1))
                        .map(String::trim)
                        .toList();
        List<String> actual = stringList(environment, name, fallback);
        if (actual == null
                || actual.stream().anyMatch(String::isEmpty)
                || new LinkedHashSet<>(actual).size() != actual.size()
                || !expected.equals(actual)) {
            throw invalid(
                    name + " обязан содержать ровно "
                            + String.join(",", expected)
                            + " в указанном порядке"
            );
        }
    }

    private static void requireSet(
            Environment environment,
            String name,
            Set<String> expected
    ) {
        List<String> values = stringList(environment, name, null);
        if (values == null || values.isEmpty()) {
            throw invalid(name + " обязателен в prod/stage");
        }
        Set<String> actual = new LinkedHashSet<>();
        for (String item : values) {
            String normalized = item.trim();
            if (normalized.isEmpty() || !actual.add(normalized)) {
                throw invalid(
                        name + " содержит пустое или повторяющееся значение"
                );
            }
        }
        if (!expected.equals(actual)) {
            throw invalid(
                    name + " обязан содержать ровно "
                            + String.join(",", expected)
            );
        }
    }

    private static void requireEmptyList(
            Environment environment,
            String name
    ) {
        List<String> values = stringList(environment, name, List.of());
        if (!values.isEmpty()) {
            throw invalid(name + " обязан быть пустым");
        }
    }

    private static void requireOneOf(
            Environment environment,
            String name,
            Set<String> allowed
    ) {
        String value = required(environment, name);
        if (!allowed.contains(value)) {
            throw invalid(name + " обязан использовать loopback address");
        }
    }

    private static void requireExact(
            Environment environment,
            String name,
            String expected
    ) {
        requireExact(environment, name, expected, null);
    }

    private static void requireExact(
            Environment environment,
            String name,
            String expected,
            String defaultValue
    ) {
        String value = property(environment, name, defaultValue);
        if (value == null || !expected.equals(value)) {
            throw invalid(name + " обязан быть равен " + expected);
        }
    }

    private static String required(Environment environment, String name) {
        String value = property(environment, name, null);
        if (value == null || value.isBlank()) {
            throw invalid(name + " обязателен в prod/stage");
        }
        return value;
    }

    private static String property(
            Environment environment,
            String name,
            String defaultValue
    ) {
        try {
            return binder(environment)
                    .bind(name, String.class)
                    .orElse(defaultValue);
        } catch (RuntimeException exception) {
            throw invalid(name + " содержит неразрешённый placeholder");
        }
    }

    private static String compactPropertyName(String value) {
        StringBuilder compact = new StringBuilder(value.length());
        value.codePoints()
                .filter(Character::isLetterOrDigit)
                .map(Character::toLowerCase)
                .forEach(compact::appendCodePoint);
        return compact.toString();
    }

    private static Map<String, String> stringMap(
            Environment environment,
            String name
    ) {
        try {
            return binder(environment)
                    .bind(
                            name,
                            Bindable.mapOf(String.class, String.class)
                    )
                    .orElseGet(Map::of);
        } catch (RuntimeException exception) {
            throw invalid(name + " содержит некорректную map-конфигурацию");
        }
    }

    private static void requireExactMap(
            Environment environment,
            String name,
            Map<String, String> expected
    ) {
        Map<String, String> actual = stringMap(environment, name);
        if (!expected.equals(actual)) {
            throw invalid(name + " обязан быть равен " + expected);
        }
    }

    private static List<String> stringList(
            Environment environment,
            String name,
            List<String> defaultValue
    ) {
        try {
            return binder(environment)
                    .bind(name, Bindable.listOf(String.class))
                    .orElse(defaultValue);
        } catch (RuntimeException exception) {
            throw invalid(name + " содержит некорректный список");
        }
    }

    private static Binder binder(Environment environment) {
        if (!(environment instanceof ConfigurableEnvironment configurable)) {
            throw invalid(
                    "protected Environment обязан предоставлять property sources"
            );
        }
        return new Binder(
                ConfigurationPropertySources.from(
                        configurable.getPropertySources()
                ),
                new PropertySourcesPlaceholdersResolver(configurable)
        );
    }

    private static IllegalStateException invalid(String message) {
        return new IllegalStateException(
                "Некорректная production operations-конфигурация: "
                        + message
        );
    }
}
