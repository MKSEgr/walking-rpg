package com.walkingrpg.backend.security;

import java.time.Duration;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SecurityModeGuardTest {

    @Test
    void shouldAllowFailClosedJwtDefaultsWithoutDevelopmentProfile() {
        assertDoesNotThrow(() -> guard(new WalkingRpgSecurityProperties()).afterPropertiesSet());
    }

    @Test
    void shouldAllowDevelopmentHeadersOnlyInLocalOrTestProfile() {
        WalkingRpgSecurityProperties local = new WalkingRpgSecurityProperties();
        local.setMode(WalkingRpgSecurityProperties.Mode.DEV_HEADER);
        local.setDemoEndpointsEnabled(true);

        assertDoesNotThrow(() -> guard(local, "local").afterPropertiesSet());
        assertDoesNotThrow(() -> guard(local, "test").afterPropertiesSet());
        assertThrows(
                IllegalStateException.class,
                () -> guard(local).afterPropertiesSet()
        );
    }

    @Test
    void shouldRejectDemoEndpointOutsideDevelopmentProfiles() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        properties.setDemoEndpointsEnabled(true);

        assertThrows(
                IllegalStateException.class,
                () -> guard(properties).afterPropertiesSet()
        );
    }

    @Test
    void shouldRejectDevelopmentSecurityOverridesInProduction() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        properties.setMode(WalkingRpgSecurityProperties.Mode.DEV_HEADER);

        assertThrows(
                IllegalStateException.class,
                () -> guard(properties, "prod").afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> guard(properties, "stage").afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> guard(new WalkingRpgSecurityProperties(), "prod", "local")
                        .afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> guard(new WalkingRpgSecurityProperties(), "stage", "test")
                        .afterPropertiesSet()
        );
        assertThrows(
                IllegalStateException.class,
                () -> guard(new WalkingRpgSecurityProperties(), "prod", "stage")
                        .afterPropertiesSet()
        );

        MockEnvironment defaultProd = new MockEnvironment()
                .withProperty("spring.profiles.default", "prod");
        assertThrows(
                IllegalStateException.class,
                () -> new SecurityModeGuard(properties, defaultProd)
                        .afterPropertiesSet()
        );
    }

    @Test
    void shouldRejectMissingOrAmbiguousIdentityMappings() {
        WalkingRpgSecurityProperties blankDevice = new WalkingRpgSecurityProperties();
        blankDevice.setDeviceClaim(" ");
        assertThrows(
                IllegalStateException.class,
                () -> guard(blankDevice).afterPropertiesSet()
        );

        WalkingRpgSecurityProperties blankAuthenticationTime =
                new WalkingRpgSecurityProperties();
        blankAuthenticationTime.setAuthenticationTimeClaim(" ");
        assertThrows(
                IllegalStateException.class,
                () -> guard(blankAuthenticationTime).afterPropertiesSet()
        );

        WalkingRpgSecurityProperties sameIdentityClaim =
                new WalkingRpgSecurityProperties();
        sameIdentityClaim.setAuthenticationTimeClaim(
                sameIdentityClaim.getDeviceClaim()
        );
        assertThrows(
                IllegalStateException.class,
                () -> guard(sameIdentityClaim).afterPropertiesSet()
        );

        WalkingRpgSecurityProperties missingUser = new WalkingRpgSecurityProperties();
        missingUser.setUserRole(" ");
        missingUser.setUserScope(null);
        assertThrows(
                IllegalStateException.class,
                () -> guard(missingUser).afterPropertiesSet()
        );

        WalkingRpgSecurityProperties sameRole = new WalkingRpgSecurityProperties();
        sameRole.setAdminRole(sameRole.getUserRole());
        assertThrows(
                IllegalStateException.class,
                () -> guard(sameRole).afterPropertiesSet()
        );

        WalkingRpgSecurityProperties sameScope = new WalkingRpgSecurityProperties();
        sameScope.setAdminScope(sameScope.getUserScope());
        assertThrows(
                IllegalStateException.class,
                () -> guard(sameScope).afterPropertiesSet()
        );
    }

    @Test
    void shouldRejectUnsafeAccountDeletionAuthenticationWindows() {
        WalkingRpgSecurityProperties disabled = new WalkingRpgSecurityProperties();
        disabled.setAccountDeletionMaxAuthenticationAge(Duration.ZERO);
        assertThrows(
                IllegalStateException.class,
                () -> guard(disabled).afterPropertiesSet()
        );

        WalkingRpgSecurityProperties tooLong = new WalkingRpgSecurityProperties();
        tooLong.setAccountDeletionMaxAuthenticationAge(Duration.ofMinutes(16));
        assertThrows(
                IllegalStateException.class,
                () -> guard(tooLong).afterPropertiesSet()
        );
    }

    private SecurityModeGuard guard(
            WalkingRpgSecurityProperties properties,
            String... profiles
    ) {
        MockEnvironment environment = new MockEnvironment();
        environment.setActiveProfiles(profiles);
        return new SecurityModeGuard(properties, environment);
    }
}
