package com.walkingrpg.backend.security;

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
        Set<String> profiles = Arrays.stream(environment.getActiveProfiles())
                .map(profile -> profile.trim().toLowerCase(Locale.ROOT))
                .collect(Collectors.toUnmodifiableSet());
        boolean productionProfile = profiles.contains("prod");
        boolean developmentProfile = profiles.stream().anyMatch(DEVELOPMENT_PROFILES::contains);

        if (productionProfile && developmentProfile) {
            throw invalid("Профиль prod нельзя совмещать с local или test");
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
        if (productionProfile
                && properties.getMode() != WalkingRpgSecurityProperties.Mode.JWT) {
            throw invalid("Профиль prod обязан использовать JWT");
        }
        if (productionProfile && properties.isDemoEndpointsEnabled()) {
            throw invalid("Профиль prod не может включать demo endpoint");
        }

        requireText(properties.getDeviceClaim(), "OIDC device claim");
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
