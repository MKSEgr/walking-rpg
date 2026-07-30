package com.walkingrpg.backend.security;

import java.time.Duration;
import java.util.Arrays;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class SecurityModeGuard implements InitializingBean {

    private static final Set<String> DEVELOPMENT_PROFILES = Set.of("local", "test");
    private static final Set<String> PROTECTED_PROFILES = Set.of("prod", "stage");
    private static final Duration MAXIMUM_ACCOUNT_DELETION_AUTHENTICATION_AGE =
            Duration.ofMinutes(15);

    private final WalkingRpgSecurityProperties properties;
    private final Environment environment;

    public SecurityModeGuard(
            WalkingRpgSecurityProperties properties,
            Environment environment
    ) {
        this.properties = properties;
        this.environment = environment;
    }

    @Override
    public void afterPropertiesSet() {
        validate();
    }

    void validate() {
        String[] active = environment.getActiveProfiles();
        String[] selectedProfiles = active.length == 0
                ? environment.getDefaultProfiles()
                : active;
        Set<String> profiles = Arrays.stream(selectedProfiles)
                .map(profile -> profile.trim().toLowerCase(Locale.ROOT))
                .collect(Collectors.toUnmodifiableSet());
        long protectedProfileCount = profiles.stream()
                .filter(PROTECTED_PROFILES::contains)
                .count();
        boolean protectedProfile = protectedProfileCount > 0;
        boolean developmentProfile = profiles.stream().anyMatch(DEVELOPMENT_PROFILES::contains);

        if (protectedProfileCount > 1 || protectedProfile && developmentProfile) {
            throw invalid(
                    "prod/stage нельзя совмещать друг с другом или с local/test"
            );
        }
        if (properties.getMode() == null) {
            throw invalid("Режим аутентификации не задан");
        }
        if (properties.getMode() == WalkingRpgSecurityProperties.Mode.DEV_HEADER
                && !developmentProfile) {
            throw invalid("DEV_HEADER разрешён только в профилях local или test");
        }
        if (properties.isDemoEndpointsEnabled() && !developmentProfile) {
            throw invalid("Demo endpoint разрешён только в профилях local или test");
        }
        if (protectedProfile
                && properties.getMode() != WalkingRpgSecurityProperties.Mode.JWT) {
            throw invalid("Профили prod/stage обязаны использовать JWT");
        }
        if (protectedProfile && properties.isDemoEndpointsEnabled()) {
            throw invalid("Профили prod/stage не могут включать demo endpoint");
        }

        requireText(properties.getDeviceClaim(), "OIDC device claim");
        requireAccountDeletionAuthenticationAge(
                properties.getAccountDeletionMaxAuthenticationAge()
        );
        requireAuthorityMapping(
                "пользовательской authority",
                properties.getUserRole(),
                properties.getUserScope()
        );
        requireAuthorityMapping(
                "административной authority",
                properties.getAdminRole(),
                properties.getAdminScope()
        );
        rejectSameMapping(
                "userRole/adminRole",
                properties.getUserRole(),
                properties.getAdminRole()
        );
        rejectSameMapping(
                "userScope/adminScope",
                properties.getUserScope(),
                properties.getAdminScope()
        );
    }

    private void requireAuthorityMapping(String name, String role, String scope) {
        if (isBlank(role) && isBlank(scope)) {
            throw invalid("Не задан mapping для " + name);
        }
    }

    private void requireAccountDeletionAuthenticationAge(Duration value) {
        if (value == null
                || value.isZero()
                || value.isNegative()
                || value.compareTo(MAXIMUM_ACCOUNT_DELETION_AUTHENTICATION_AGE) > 0) {
            throw invalid(
                    "допустимый возраст authentication для удаления аккаунта "
                            + "должен быть от PT0S до PT15M"
            );
        }
    }

    private void rejectSameMapping(String name, String left, String right) {
        String normalizedLeft = normalizeAuthorityValue(left);
        String normalizedRight = normalizeAuthorityValue(right);
        if (normalizedLeft != null && normalizedLeft.equals(normalizedRight)) {
            throw invalid("Совпадают security mappings " + name);
        }
    }

    private void requireText(String value, String name) {
        if (isBlank(value)) {
            throw invalid(name + " не задан");
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private String normalizeAuthorityValue(String value) {
        if (isBlank(value)) {
            return null;
        }
        return value.trim().toUpperCase(Locale.ROOT).replace('-', '_');
    }

    private IllegalStateException invalid(String message) {
        return new IllegalStateException("Некорректная security-конфигурация: " + message);
    }
}
