package com.walkingrpg.backend.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.DateTimeException;
import java.time.Duration;
import java.time.Instant;
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

    private static final Duration FUTURE_AUTHENTICATION_CLOCK_SKEW =
            Duration.ofSeconds(30);

    private final WalkingRpgSecurityProperties properties;
    private final AccountDeletionRegistry accountDeletionRegistry;
    private final Clock clock;

    @Autowired
    public SecurityContextRequestIdentityProvider(
            WalkingRpgSecurityProperties properties,
            AccountDeletionRegistry accountDeletionRegistry,
            Clock clock
    ) {
        this.properties = properties;
        this.accountDeletionRegistry = accountDeletionRegistry;
        this.clock = clock;
    }

    /**
     * Test-only convenience constructor for isolated security mapping tests.
     */
    SecurityContextRequestIdentityProvider(WalkingRpgSecurityProperties properties) {
        this.properties = properties;
        this.accountDeletionRegistry = null;
        this.clock = Clock.systemUTC();
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
        RequestIdentity identity = resolveIdentity().orElseThrow(() ->
                new AuthenticationCredentialsNotFoundException("Требуется аутентификация")
        );
        requireFreshAuthentication();
        return identity;
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

    private void requireFreshAuthentication() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        Jwt jwt;
        if (authentication instanceof JwtAuthenticationToken jwtAuthentication) {
            jwt = jwtAuthentication.getToken();
        } else if (authentication != null && authentication.getPrincipal() instanceof Jwt token) {
            jwt = token;
        } else {
            throw freshAuthenticationRequired(
                    "Удаление аккаунта требует подтверждённого OIDC-входа"
            );
        }

        Instant authenticatedAt = authenticationTime(jwt);
        Instant now = clock.instant();
        Duration maximumAge = properties.getAccountDeletionMaxAuthenticationAge();
        if (authenticatedAt.isBefore(now.minus(maximumAge))) {
            throw freshAuthenticationRequired(
                    "Подтверждение личности для удаления аккаунта устарело"
            );
        }
        if (authenticatedAt.isAfter(now.plus(FUTURE_AUTHENTICATION_CLOCK_SKEW))) {
            throw freshAuthenticationRequired(
                    "Время подтверждения личности находится в будущем"
            );
        }
    }

    private Instant authenticationTime(Jwt jwt) {
        Object claim = jwt.getClaims().get("auth_time");
        if (claim instanceof Instant instant) {
            return instant;
        }
        if (claim instanceof Number number) {
            double rawValue = number.doubleValue();
            long epochSecond = number.longValue();
            if (!Double.isFinite(rawValue) || rawValue != (double) epochSecond) {
                throw freshAuthenticationRequired(
                        "JWT содержит некорректный auth_time"
                );
            }
            try {
                return Instant.ofEpochSecond(epochSecond);
            } catch (DateTimeException exception) {
                throw freshAuthenticationRequired(
                        "JWT содержит некорректный auth_time"
                );
            }
        }
        throw freshAuthenticationRequired(
                "JWT не содержит обязательный auth_time для удаления аккаунта"
        );
    }

    private FreshAuthenticationRequiredException freshAuthenticationRequired(
            String message
    ) {
        return new FreshAuthenticationRequiredException(
                message,
                properties.getAccountDeletionMaxAuthenticationAge()
        );
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
