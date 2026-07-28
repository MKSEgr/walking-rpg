package com.walkingrpg.backend.security;

import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SecurityContextRequestIdentityProviderTest {

    private final WalkingRpgSecurityProperties properties =
            new WalkingRpgSecurityProperties();
    private final SecurityContextRequestIdentityProvider provider =
            new SecurityContextRequestIdentityProvider(properties);

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void shouldResolveSubjectActorAndHashedDeviceFromJwt() {
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer("https://identity.example.com")
                .subject("subject-123")
                .claim("preferred_username", "walker")
                .claim("sid", "browser-session-9")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300))
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(
                        jwt,
                        List.of(new SimpleGrantedAuthority("ROLE_USER")),
                        "walker"
                )
        );

        RequestIdentity identity = provider.requireIdentity();

        assertEquals("subject-123", identity.userId());
        assertEquals("walker", identity.actor());
        assertEquals(64, identity.requireDeviceId().length());
        assertNotEquals("browser-session-9", identity.deviceId());
        assertTrue(identity.authorities().contains("ROLE_USER"));
    }

    @Test
    void shouldResolveDevelopmentPrincipalWithoutTrustingControllerHeaders() {
        WalkingRpgPrincipal principal = new WalkingRpgPrincipal(
                "dev-user",
                "local-admin",
                "dev-device"
        );
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        principal,
                        null,
                        List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))
                )
        );

        RequestIdentity identity = provider.requireIdentity();

        assertEquals("dev-user", identity.userId());
        assertEquals("local-admin", identity.actor());
        assertEquals("dev-device", identity.requireDeviceId());
    }


    @Test
    void shouldUseOnlyConfiguredDeviceClaim() {
        properties.setDeviceClaim("device_id");
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer("https://identity.example.com")
                .subject("subject-123")
                .claim("sid", "session-should-not-be-used")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300))
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(
                        jwt,
                        List.of(new SimpleGrantedAuthority("ROLE_USER"))
                )
        );

        assertThrows(
                MissingDeviceIdentityException.class,
                () -> provider.requireIdentity().requireDeviceId()
        );
    }

    @Test
    void shouldRejectMissingAuthentication() {
        assertFalse(provider.currentIdentity().isPresent());
        assertThrows(
                org.springframework.security.authentication.AuthenticationCredentialsNotFoundException.class,
                provider::requireIdentity
        );
    }

    @Test
    void shouldRejectActivityDeviceWhenTokenHasNoSessionClaim() {
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer("https://identity.example.com")
                .subject("subject-123")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300))
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(
                        jwt,
                        List.of(new SimpleGrantedAuthority("ROLE_USER"))
                )
        );

        assertThrows(
                MissingDeviceIdentityException.class,
                () -> provider.requireIdentity().requireDeviceId()
        );
    }
}
