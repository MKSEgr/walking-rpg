package com.walkingrpg.backend.security;

import java.math.BigDecimal;
import java.math.BigInteger;
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

    private static final int MAXIMUM_PERSISTED_IDENTITY_LENGTH = 128;
    private static final Duration FUTURE_AUTHENTICATION_CLOCK_SKEW =
            Duration.ofSeconds(30);
    private static final BigInteger NANOSECONDS_PER_SECOND =
            BigInteger.valueOf(1_000_000_000L);

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
            try {
                return requireExactNumericDate(number);
            } catch (ArithmeticException | DateTimeException
                    | NumberFormatException exception) {
                throw invalidAuthenticationTime();
            }
        }
        throw freshAuthenticationRequired(
                "JWT не содержит обязательный auth_time для удаления аккаунта"
        );
    }

    private Instant requireExactNumericDate(Number number) {
        BigInteger totalNanoseconds = exactDecimal(number)
                .movePointRight(9)
                .toBigIntegerExact();
        BigInteger[] secondAndNanosecond = totalNanoseconds.divideAndRemainder(
                NANOSECONDS_PER_SECOND
        );
        return Instant.ofEpochSecond(
                secondAndNanosecond[0].longValueExact(),
                secondAndNanosecond[1].longValueExact()
        );
    }

    private BigDecimal exactDecimal(Number number) {
        if (number instanceof BigDecimal decimal) {
            return decimal;
        }
        if (number instanceof BigInteger integer) {
            return new BigDecimal(integer);
        }
        if (number instanceof Byte
                || number instanceof Short
                || number instanceof Integer
                || number instanceof Long) {
            return BigDecimal.valueOf(number.longValue());
        }
        if (number instanceof Float || number instanceof Double) {
            throw new NumberFormatException("Lossy floating-point auth_time");
        }
        return new BigDecimal(number.toString());
    }

    private FreshAuthenticationRequiredException invalidAuthenticationTime() {
        return freshAuthenticationRequired(
                "JWT содержит некорректный auth_time"
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
        String subject = requireExactClaim(
                jwt.getSubject(),
                "sub",
                MAXIMUM_PERSISTED_IDENTITY_LENGTH
        );
        String actor = optionalExactStringClaim(
                jwt,
                properties.getUsernameClaim(),
                MAXIMUM_PERSISTED_IDENTITY_LENGTH
        ).orElse(subject);
        String deviceSeed = optionalExactStringClaim(
                jwt,
                properties.getDeviceClaim(),
                null
        ).orElse(null);
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

    private Optional<String> optionalExactStringClaim(
            Jwt jwt,
            String claimName,
            Integer maximumLength
    ) {
        if (claimName == null || claimName.isBlank()) {
            return Optional.empty();
        }
        Object current = jwt.getClaims();
        for (String part : claimName.split("\\.", -1)) {
            if (part.isEmpty()) {
                throw invalidIdentityClaim(claimName);
            }
            if (!(current instanceof java.util.Map<?, ?> map)) {
                throw invalidIdentityClaim(claimName);
            }
            if (!map.containsKey(part)) {
                return Optional.empty();
            }
            current = map.get(part);
        }
        if (!(current instanceof String text)) {
            throw invalidIdentityClaim(claimName);
        }
        return Optional.of(requireExactClaim(text, claimName, maximumLength));
    }

    private String requireExactClaim(
            String value,
            String claimName,
            Integer maximumLength
    ) {
        if (value == null) {
            throw new AuthenticationCredentialsNotFoundException(
                    "JWT не содержит обязательный claim " + claimName
            );
        }
        if (value.isBlank()
                || hasBoundaryWhitespace(value)
                || value.codePoints().anyMatch(Character::isISOControl)) {
            throw invalidIdentityClaim(claimName);
        }
        if (maximumLength != null && value.length() > maximumLength) {
            throw invalidIdentityClaim(claimName);
        }
        return value;
    }

    private boolean hasBoundaryWhitespace(String value) {
        int first = value.codePointAt(0);
        int last = value.codePointBefore(value.length());
        return Character.isWhitespace(first)
                || Character.isSpaceChar(first)
                || Character.isWhitespace(last)
                || Character.isSpaceChar(last);
    }

    private AuthenticationCredentialsNotFoundException invalidIdentityClaim(
            String claimName
    ) {
        return new AuthenticationCredentialsNotFoundException(
                "JWT содержит некорректный identity claim " + claimName
        );
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
