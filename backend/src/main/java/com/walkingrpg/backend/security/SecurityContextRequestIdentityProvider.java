package com.walkingrpg.backend.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public class SecurityContextRequestIdentityProvider implements RequestIdentityProvider {

    private final WalkingRpgSecurityProperties properties;
    private final AccountDeletionRegistry accountDeletionRegistry;

    @Autowired
    public SecurityContextRequestIdentityProvider(
            WalkingRpgSecurityProperties properties,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.properties = properties;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    /**
     * Test-only convenience constructor for isolated security mapping tests.
     */
    SecurityContextRequestIdentityProvider(WalkingRpgSecurityProperties properties) {
        this.properties = properties;
        this.accountDeletionRegistry = null;
    }

    @Override
    public RequestIdentity requireIdentity() {
        RequestIdentity identity = resolveIdentity().orElseThrow(() ->
                new AuthenticationCredentialsNotFoundException("Требуется аутентификация")
        );
        requireActive(identity);
        return identity;
    }

    @Override
    public RequestIdentity requireIdentityForAccountDeletion() {
        return resolveIdentity().orElseThrow(() ->
                new AuthenticationCredentialsNotFoundException("Требуется аутентификация")
        );
    }

    @Override
    public Optional<RequestIdentity> currentIdentity() {
        Optional<RequestIdentity> identity = resolveIdentity();
        identity.ifPresent(this::requireActive);
        return identity;
    }

    private Optional<RequestIdentity> resolveIdentity() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication instanceof AnonymousAuthenticationToken) {
            return Optional.empty();
        }

        Set<String> authorities = authentication.getAuthorities().stream()
                .map(authority -> authority.getAuthority())
                .collect(Collectors.toUnmodifiableSet());

        Object principal = authentication.getPrincipal();
        if (principal instanceof WalkingRpgPrincipal walkingPrincipal) {
            return Optional.of(new RequestIdentity(
                    walkingPrincipal.userId(),
                    walkingPrincipal.actor(),
                    walkingPrincipal.deviceId(),
                    authorities
            ));
        }
        if (authentication instanceof JwtAuthenticationToken jwtAuthentication) {
            return Optional.of(fromJwt(jwtAuthentication.getToken(), authorities));
        }
        if (principal instanceof Jwt jwt) {
            return Optional.of(fromJwt(jwt, authorities));
        }

        return Optional.empty();
    }

    private void requireActive(RequestIdentity identity) {
        if (accountDeletionRegistry != null) {
            accountDeletionRegistry.requireActive(identity.userId());
        }
    }

    private RequestIdentity fromJwt(Jwt jwt, Set<String> authorities) {
        String subject = requireClaim(jwt.getSubject(), "sub");
        String actor = optionalStringClaim(jwt, properties.getUsernameClaim()).orElse(subject);
        String deviceSeed = optionalStringClaim(jwt, properties.getDeviceClaim()).orElse(null);
        String deviceId = deviceSeed == null
                ? null
                : sha256Hex(
                        requireIssuer(jwt)
                                + "|"
                                + subject
                                + "|"
                                + properties.getDeviceClaim()
                                + "|"
                                + deviceSeed
                );
        return new RequestIdentity(subject, actor, deviceId, authorities);
    }

    private Optional<String> optionalStringClaim(Jwt jwt, String claimName) {
        if (claimName == null || claimName.isBlank()) {
            return Optional.empty();
        }
        Object current = jwt.getClaims();
        for (String part : claimName.split("\\.")) {
            if (!(current instanceof java.util.Map<?, ?> map)) {
                return Optional.empty();
            }
            current = map.get(part);
        }
        if (current instanceof String text && !text.isBlank()) {
            return Optional.of(text.trim());
        }
        return Optional.empty();
    }

    private String requireClaim(String value, String claimName) {
        if (value == null || value.isBlank()) {
            throw new AuthenticationCredentialsNotFoundException(
                    "JWT не содержит обязательный claim " + claimName
            );
        }
        return value.trim();
    }

    private String requireIssuer(Jwt jwt) {
        var issuer = jwt.getIssuer();
        if (issuer == null) {
            throw new AuthenticationCredentialsNotFoundException(
                    "JWT не содержит обязательный claim iss для device identity"
            );
        }
        return issuer.toString();
    }

    private String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }
}
