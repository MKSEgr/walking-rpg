package com.walkingrpg.backend.security;

import java.time.Instant;
import java.util.List;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
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
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

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
    void shouldResolveSubjectActorAndHashedStableDeviceFromJwt() {
        Jwt jwt = jwtBuilder()
                .claim("preferred_username", "walker")
                .claim("device_id", "installation-9")
                .build();
        authenticate(jwt);

        RequestIdentity identity = provider.requireIdentity();

        assertEquals("subject-123", identity.userId());
        assertEquals("walker", identity.actor());
        assertEquals(64, identity.requireDeviceId().length());
        assertNotEquals("installation-9", identity.deviceId());
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
    void shouldUseOnlyConfiguredStableDeviceClaim() {
        properties.setDeviceClaim("installation_id");
        Jwt jwt = jwtBuilder()
                .claim("sid", "session-should-not-be-used")
                .claim("installation_id", "installation-42")
                .build();
        authenticate(jwt);

        RequestIdentity identity = provider.requireIdentity();

        assertEquals(64, identity.requireDeviceId().length());
        assertNotEquals("installation-42", identity.deviceId());
    }

    @Test
    void shouldRejectSessionIdWhenStableDeviceClaimIsMissing() {
        Jwt jwt = jwtBuilder()
                .claim("sid", "rotating-session-id")
                .build();
        authenticate(jwt);

        assertThrows(
                MissingDeviceIdentityException.class,
                () -> provider.requireIdentity().requireDeviceId()
        );
    }

    @Test
    void shouldRequireIssuerWhenDerivingDeviceIdentity() {
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .subject("subject-123")
                .claim("device_id", "installation-9")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300))
                .build();
        authenticate(jwt);

        assertThrows(
                AuthenticationCredentialsNotFoundException.class,
                provider::requireIdentity
        );
    }

    @Test
    void shouldRejectMissingAuthentication() {
        assertFalse(provider.currentIdentity().isPresent());
        assertThrows(
                AuthenticationCredentialsNotFoundException.class,
                provider::requireIdentity
        );
    }

    @Test
    void shouldRejectUnknownAuthenticatedPrincipalType() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        "untrusted-principal",
                        null,
                        List.of(new SimpleGrantedAuthority("ROLE_USER"))
                )
        );

        assertFalse(provider.currentIdentity().isPresent());
        assertThrows(
                AuthenticationCredentialsNotFoundException.class,
                provider::requireIdentity
        );
    }

    @Test
    void shouldRejectActivityDeviceWhenTokenHasNoStableDeviceClaim() {
        authenticate(jwtBuilder().build());

        assertThrows(
                MissingDeviceIdentityException.class,
                () -> provider.requireIdentity().requireDeviceId()
        );
    }

    @Test
    void shouldRejectADeletedSubjectButAllowDeletionReceiptReplay() {
        AccountDeletionRegistry registry = mock(AccountDeletionRegistry.class);
        SecurityContextRequestIdentityProvider guardedProvider =
                new SecurityContextRequestIdentityProvider(properties, registry);
        authenticate(jwtBuilder().build());
        doThrow(new AccountDeletedException())
                .when(registry)
                .requireActive("subject-123");

        assertThrows(AccountDeletedException.class, guardedProvider::requireIdentity);
        assertEquals(
                "subject-123",
                guardedProvider.requireIdentityForAccountDeletion().userId()
        );
        verify(registry).requireActive("subject-123");
    }

    private void authenticate(Jwt jwt) {
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(
                        jwt,
                        List.of(new SimpleGrantedAuthority("ROLE_USER")),
                        "walker"
                )
        );
    }

    private Jwt.Builder jwtBuilder() {
        Instant now = Instant.parse("2026-07-28T06:00:00Z");
        return Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer("https://identity.example.com")
                .subject("subject-123")
                .issuedAt(now)
                .expiresAt(now.plusSeconds(300));
    }
}
