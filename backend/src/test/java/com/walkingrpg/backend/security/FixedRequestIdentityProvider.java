package com.walkingrpg.backend.security;

import java.util.Optional;
import java.util.Set;

public final class FixedRequestIdentityProvider implements RequestIdentityProvider {

    private final RequestIdentity identity;

    private FixedRequestIdentityProvider(RequestIdentity identity) {
        this.identity = identity;
    }

    public static FixedRequestIdentityProvider user(String userId) {
        return new FixedRequestIdentityProvider(new RequestIdentity(
                userId,
                userId,
                "test-device",
                Set.of("ROLE_USER")
        ));
    }

    public static FixedRequestIdentityProvider user(String userId, String deviceId) {
        return new FixedRequestIdentityProvider(new RequestIdentity(
                userId,
                userId,
                deviceId,
                Set.of("ROLE_USER")
        ));
    }

    public static FixedRequestIdentityProvider admin(String userId, String actor) {
        return new FixedRequestIdentityProvider(new RequestIdentity(
                userId,
                actor,
                "test-device",
                Set.of("ROLE_USER", "ROLE_ADMIN")
        ));
    }

    public static FixedRequestIdentityProvider anonymous() {
        return new FixedRequestIdentityProvider(null);
    }

    @Override
    public RequestIdentity requireIdentity() {
        if (identity == null) {
            throw new org.springframework.security.authentication.AuthenticationCredentialsNotFoundException(
                    "Требуется аутентификация"
            );
        }
        return identity;
    }

    @Override
    public Optional<RequestIdentity> currentIdentity() {
        return Optional.ofNullable(identity);
    }
}
