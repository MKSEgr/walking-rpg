package com.walkingrpg.backend.security;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.oauth2.jwt.Jwt;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtAuthorityConverterTest {

    @Test
    void shouldMapConfiguredRolesAndScopesToApplicationAuthorities() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        JwtAuthorityConverter converter = new JwtAuthorityConverter(properties);
        Jwt jwt = jwtBuilder()
                .claim("preferred_username", "walker")
                .claim("roles", List.of("walking-rpg-admin"))
                .claim("scope", "openid walking-rpg.user")
                .build();

        AbstractAuthenticationToken authentication = converter.convert(jwt);
        Set<String> authorities = authorities(authentication);

        assertEquals("walker", authentication.getName());
        assertTrue(authorities.contains("ROLE_USER"));
        assertTrue(authorities.contains("ROLE_ADMIN"));
        assertTrue(authorities.contains("SCOPE_openid"));
        assertTrue(authorities.contains("SCOPE_walking-rpg.user"));
    }

    @Test
    void shouldReadNestedKeycloakRoleClaim() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        properties.setRolesClaim("realm_access.roles");
        JwtAuthorityConverter converter = new JwtAuthorityConverter(properties);
        Jwt jwt = jwtBuilder()
                .claim("realm_access", java.util.Map.of(
                        "roles", List.of("walking-rpg-user")
                ))
                .build();

        AbstractAuthenticationToken authentication = converter.convert(jwt);

        assertTrue(authorities(authentication).contains("ROLE_USER"));
    }

    @Test
    void shouldNotGrantApplicationRoleForUnrelatedClaims() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        JwtAuthorityConverter converter = new JwtAuthorityConverter(properties);
        Jwt jwt = jwtBuilder()
                .claim("roles", List.of("report-reader"))
                .claim("scope", "openid profile")
                .build();

        AbstractAuthenticationToken authentication = converter.convert(jwt);

        assertTrue(authorities(authentication).stream()
                .noneMatch(authority -> authority.startsWith("ROLE_")));
    }

    @Test
    void shouldNotTreatGenericUserOrAdminRoleNamesAsApplicationRoles() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        JwtAuthorityConverter converter = new JwtAuthorityConverter(properties);
        Jwt jwt = jwtBuilder()
                .claim("roles", List.of("USER", "ADMIN", "ROLE_USER", "ROLE_ADMIN"))
                .build();

        AbstractAuthenticationToken authentication = converter.convert(jwt);

        assertTrue(authorities(authentication).stream()
                .noneMatch(authority -> authority.startsWith("ROLE_")));
    }

    @Test
    void shouldAllowGenericLookingRoleOnlyWhenExplicitlyConfigured() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        properties.setAdminRole("ROLE_ADMIN");
        JwtAuthorityConverter converter = new JwtAuthorityConverter(properties);
        Jwt jwt = jwtBuilder()
                .claim("roles", List.of("ROLE_ADMIN"))
                .build();

        Set<String> authorities = authorities(converter.convert(jwt));

        assertTrue(authorities.contains("ROLE_ADMIN"));
        assertTrue(authorities.contains("ROLE_USER"));
    }

    @Test
    void shouldRejectTokenWithoutSubject() {
        WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
        JwtAuthorityConverter converter = new JwtAuthorityConverter(properties);
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer("https://identity.example.com")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300))
                .build();

        assertThrows(
                org.springframework.security.oauth2.core.OAuth2AuthenticationException.class,
                () -> converter.convert(jwt)
        );
    }

    private Set<String> authorities(AbstractAuthenticationToken authentication) {
        return authentication.getAuthorities().stream()
                .map(authority -> authority.getAuthority())
                .collect(Collectors.toSet());
    }

    private Jwt.Builder jwtBuilder() {
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        return Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer("https://identity.example.com")
                .subject("user-1")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300));
    }
}
