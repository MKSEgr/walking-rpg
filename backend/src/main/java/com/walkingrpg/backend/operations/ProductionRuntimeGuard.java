package com.walkingrpg.backend.operations;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import com.walkingrpg.backend.platform.config.PlatformProviderProperties;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.EnumerablePropertySource;
import org.springframework.core.env.Environment;
import org.springframework.core.env.PropertySource;
import org.springframework.stereotype.Component;

@Component
public class ProductionRuntimeGuard implements InitializingBean {

    static final String POSTGRESQL_JDBC_PREFIX = "jdbc:postgresql://";
    static final Set<String> DEVELOPMENT_PROFILES = Set.of("local", "test");
    static final Set<String> PROTECTED_PROFILES = Set.of("prod", "stage");

    private static final Set<String> PAYMENT_MODES = Set.of("disabled", "sandbox");
    private static final Set<String> PUSH_MODES = Set.of("disabled", "development");
    private static final Set<String> ALLOWED_JDBC_PARAMETERS = Set.of("sslmode");
    private static final String HIKARI_CONFIGURATION_FILE_PROPERTY =
            "hikaricp.configurationFile";
    private static final String HIKARI_PROPERTIES_PREFIX =
            "springdatasourcehikari";
    private static final String HIKARI_DATA_SOURCE_PROPERTIES_PREFIX =
            "springdatasourcehikaridatasourceproperties";
    private static final Set<String> HIKARI_CONNECTION_PROPERTY_SUFFIXES = Set.of(
            "credentialsprovider",
            "credentialsproviderclassname",
            "datasourceclassname",
            "datasourcejndi",
            "driverclassname",
            "jdbcurl",
            "password",
            "username"
    );
    private static final String FLYWAY_PROPERTIES_PREFIX = "springflyway";
    private static final String FLYWAY_JDBC_PROPERTIES_PREFIX =
            "springflywayjdbcproperties";
    private static final Set<String> FLYWAY_CONNECTION_PROPERTY_SUFFIXES = Set.of(
            "driverclassname",
            "password",
            "url",
            "user"
    );
    private static final Set<String> UNSAFE_DATABASE_USERS =
            Set.of("postgres", "root", "walking_rpg");
    private static final List<String> ALTERNATE_CONNECTION_PROPERTIES = List.of(
            HIKARI_CONFIGURATION_FILE_PROPERTY,
            "spring.datasource.hikari.jdbc-url",
            "spring.datasource.hikari.username",
            "spring.datasource.hikari.password",
            "spring.datasource.hikari.data-source-class-name",
            "spring.datasource.hikari.data-source-properties.url",
            "spring.datasource.hikari.data-source-properties.user",
            "spring.datasource.hikari.data-source-properties.password",
            "spring.datasource.jndi-name",
            "spring.datasource.type",
            "spring.flyway.url",
            "spring.flyway.user",
            "spring.flyway.password"
    );
    private static final Pattern SAFE_HOST = Pattern.compile(
            "(?i)[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?"
                    + "(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*"
    );

    private final PlatformProviderProperties properties;
    private final Environment environment;

    public ProductionRuntimeGuard(
            PlatformProviderProperties properties,
            Environment environment
    ) {
        this.properties = properties;
        this.environment = environment;
    }

    @Override
    public void afterPropertiesSet() {
        validateProtectedEnvironment(environment);
        validateProviderModes(
                effectiveProfiles(environment),
                properties.getPayment(),
                properties.getPush()
        );
    }

    static void validateProtectedEnvironment(Environment environment) {
        Set<String> profiles = effectiveProfiles(environment);
        validateProfileTopology(profiles);
        String payment = property(
                environment,
                "walking-rpg.providers.payment",
                "disabled"
        );
        String push = property(
                environment,
                "walking-rpg.providers.push",
                "disabled"
        );
        validateProviderModes(profiles, payment, push);

        if (profiles.stream().noneMatch(PROTECTED_PROFILES::contains)) {
            return;
        }
        rejectAlternateConnectionProperties(environment);
        validateJdbcUrl(required(environment, "spring.datasource.url"));
        validateUsername(required(environment, "spring.datasource.username"));
        validatePassword(required(environment, "spring.datasource.password"));

        String flywayEnabled = property(environment, "spring.flyway.enabled", null);
        if (!"true".equalsIgnoreCase(normalize(flywayEnabled))) {
            throw invalid("Flyway должен быть включён в prod/stage");
        }
        String driver = property(
                environment,
                "spring.datasource.driver-class-name",
                null
        );
        if (hasText(driver) && !"org.postgresql.Driver".equals(driver)) {
            throw invalid("разрешён только PostgreSQL JDBC driver");
        }
    }

    private static void validateProfileTopology(Set<String> profiles) {
        long protectedCount = profiles.stream().filter(PROTECTED_PROFILES::contains).count();
        boolean development = profiles.stream().anyMatch(DEVELOPMENT_PROFILES::contains);
        if (protectedCount > 1 || protectedCount > 0 && development) {
            throw invalid(
                    "prod/stage нельзя совмещать друг с другом или с local/test"
            );
        }
    }

    private static void validateProviderModes(
            Set<String> profiles,
            String payment,
            String push
    ) {
        validateProfileTopology(profiles);
        boolean development = profiles.stream().anyMatch(DEVELOPMENT_PROFILES::contains);
        boolean protectedRuntime = profiles.stream().anyMatch(PROTECTED_PROFILES::contains);
        if (!PAYMENT_MODES.contains(payment)) {
            throw invalid("неизвестный payment provider: " + display(payment));
        }
        if (!PUSH_MODES.contains(push)) {
            throw invalid("неизвестный push provider: " + display(push));
        }
        if (protectedRuntime
                && (!"disabled".equals(payment) || !"disabled".equals(push))) {
            throw invalid("prod/stage обязаны отключать payment и push providers");
        }
        if (!development && "sandbox".equals(payment)) {
            throw invalid("sandbox payment разрешён только в local/test");
        }
        if (!development && "development".equals(push)) {
            throw invalid("development push разрешён только в local/test");
        }
    }

    private static void rejectAlternateConnectionProperties(Environment environment) {
        Set<String> configured = ALTERNATE_CONNECTION_PROPERTIES.stream()
                .filter(name -> hasText(property(environment, name, null)))
                .collect(Collectors.toCollection(TreeSet::new));
        configured.addAll(enumeratedConnectionProperties(environment));
        if (!configured.isEmpty()) {
            throw invalid(
                    "альтернативные datasource/Flyway connection properties запрещены: "
                            + String.join(", ", configured)
            );
        }
    }

    private static Set<String> enumeratedConnectionProperties(
            Environment environment
    ) {
        Set<String> configured = new TreeSet<>();
        if (!(environment instanceof ConfigurableEnvironment configurableEnvironment)) {
            return configured;
        }
        for (PropertySource<?> propertySource
                : configurableEnvironment.getPropertySources()) {
            if (!(propertySource instanceof EnumerablePropertySource<?> enumerable)) {
                continue;
            }
            for (String name : enumerable.getPropertyNames()) {
                String compactName = compactPropertyName(name);
                if ((isHikariConnectionProperty(compactName)
                        || isFlywayConnectionProperty(compactName))
                        && propertySource.getProperty(name) != null) {
                    configured.add(name);
                }
            }
        }
        return configured;
    }

    private static boolean isHikariConnectionProperty(String compactName) {
        if (compactName.startsWith(HIKARI_DATA_SOURCE_PROPERTIES_PREFIX)) {
            return true;
        }
        if (!compactName.startsWith(HIKARI_PROPERTIES_PREFIX)) {
            return false;
        }
        String suffix = compactName.substring(HIKARI_PROPERTIES_PREFIX.length());
        return HIKARI_CONNECTION_PROPERTY_SUFFIXES.contains(suffix);
    }

    private static boolean isFlywayConnectionProperty(String compactName) {
        if (compactName.startsWith(FLYWAY_JDBC_PROPERTIES_PREFIX)) {
            return true;
        }
        if (!compactName.startsWith(FLYWAY_PROPERTIES_PREFIX)) {
            return false;
        }
        String suffix = compactName.substring(FLYWAY_PROPERTIES_PREFIX.length());
        return FLYWAY_CONNECTION_PROPERTY_SUFFIXES.contains(suffix);
    }

    private static void validateJdbcUrl(String url) {
        if (!url.equals(url.trim())) {
            throw invalid("пробелы по краям spring.datasource.url запрещены");
        }
        if (!url.startsWith(POSTGRESQL_JDBC_PREFIX)) {
            throw invalid("spring.datasource.url обязан использовать PostgreSQL JDBC");
        }
        if (url.indexOf('#') >= 0) {
            throw invalid("fragment в spring.datasource.url запрещён");
        }

        String target = url.substring(POSTGRESQL_JDBC_PREFIX.length());
        int slash = target.indexOf('/');
        if (slash <= 0 || slash == target.length() - 1) {
            throw invalid("spring.datasource.url обязан содержать host и database");
        }
        String authority = target.substring(0, slash);
        String databaseAndQuery = target.substring(slash + 1);
        if (authority.indexOf('@') >= 0) {
            throw invalid("credentials в spring.datasource.url запрещены");
        }
        if (authority.indexOf(',') >= 0) {
            throw invalid("multi-host spring.datasource.url запрещён");
        }
        validateHost(authority);

        int question = databaseAndQuery.indexOf('?');
        String database = question < 0
                ? databaseAndQuery
                : databaseAndQuery.substring(0, question);
        if (!hasText(database)
                || !database.equals(database.trim())
                || database.indexOf('/') >= 0) {
            throw invalid("spring.datasource.url содержит некорректное имя database");
        }
        String query = question < 0 ? "" : databaseAndQuery.substring(question + 1);
        validateQuery(query);
    }

    private static void validateHost(String authority) {
        if (!authority.equals(authority.trim())
                || authority.isEmpty()
                || authority.startsWith("[")) {
            throw invalid("IPv6/пустой host в prod/stage datasource не разрешён");
        }
        String hostAndPort = authority;
        int colon = hostAndPort.lastIndexOf(':');
        String host = colon < 0 ? hostAndPort : hostAndPort.substring(0, colon);
        String port = colon < 0 ? null : hostAndPort.substring(colon + 1);
        if (host.length() > 253 || !SAFE_HOST.matcher(host).matches()) {
            throw invalid(
                    "spring.datasource.url обязан использовать канонический DNS host"
            );
        }
        String normalizedHost = host.toLowerCase(Locale.ROOT);
        if ("localhost".equals(normalizedHost)
                || normalizedHost.endsWith(".localhost")
                || "0.0.0.0".equals(normalizedHost)
                || normalizedHost.startsWith("127.")) {
            throw invalid("loopback/local datasource запрещён в prod/stage");
        }
        if (port != null) {
            try {
                int value = Integer.parseInt(port);
                if (value < 1 || value > 65_535) {
                    throw invalid("port datasource вне допустимого диапазона");
                }
            } catch (NumberFormatException exception) {
                throw invalid("некорректный port в spring.datasource.url");
            }
        }
    }

    private static void validateQuery(String query) {
        if (query.isBlank()) {
            throw invalid("spring.datasource.url обязан задавать sslmode=verify-full");
        }
        Set<String> parameters = new HashSet<>();
        String sslMode = null;
        for (String pair : query.split("&", -1)) {
            if (pair.isBlank()) {
                throw invalid("пустой JDBC parameter запрещён");
            }
            int equals = pair.indexOf('=');
            String rawName = equals < 0 ? pair : pair.substring(0, equals);
            String rawValue = equals < 0 ? "" : pair.substring(equals + 1);
            if (rawName.isEmpty()) {
                throw invalid("пустое имя JDBC parameter запрещено");
            }
            if (!parameters.add(rawName)) {
                throw invalid("duplicate JDBC parameters запрещены: " + rawName);
            }
            if (!ALLOWED_JDBC_PARAMETERS.contains(rawName)) {
                throw invalid(
                        "в spring.datasource.url разрешён только JDBC parameter sslmode"
                );
            }
            sslMode = rawValue;
        }
        if (!"verify-full".equals(sslMode)) {
            throw invalid("spring.datasource.url обязан задавать ровно sslmode=verify-full");
        }
    }

    private static void validateUsername(String username) {
        String normalized = username.trim().toLowerCase(Locale.ROOT);
        if (UNSAFE_DATABASE_USERS.contains(normalized)) {
            throw invalid("production datasource обязан использовать отдельного app-user");
        }
    }

    private static void validatePassword(String password) {
        if ("walking_rpg_local".equals(password)) {
            throw invalid("локальный database password запрещён в prod/stage");
        }
    }

    private static String required(Environment environment, String name) {
        String value = property(environment, name, null);
        if (!hasText(value)) {
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
            return environment.getProperty(name, defaultValue);
        } catch (IllegalArgumentException exception) {
            throw invalid(name + " содержит неразрешённый placeholder");
        }
    }

    private static Set<String> effectiveProfiles(Environment environment) {
        String[] active = environment.getActiveProfiles();
        String[] profiles = active.length == 0
                ? environment.getDefaultProfiles()
                : active;
        return Arrays.stream(profiles)
                .map(ProductionRuntimeGuard::normalize)
                .filter(value -> !value.isEmpty())
                .collect(Collectors.toUnmodifiableSet());
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    }

    private static String compactPropertyName(String value) {
        StringBuilder compact = new StringBuilder(value.length());
        value.codePoints()
                .filter(Character::isLetterOrDigit)
                .map(Character::toLowerCase)
                .forEach(compact::appendCodePoint);
        return compact.toString();
    }

    private static String display(String value) {
        return value == null || value.isEmpty() ? "<empty>" : value;
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private static IllegalStateException invalid(String message) {
        return new IllegalStateException(
                "Некорректная production runtime-конфигурация: " + message
        );
    }
}
