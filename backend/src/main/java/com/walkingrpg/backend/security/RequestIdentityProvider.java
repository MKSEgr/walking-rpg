package com.walkingrpg.backend.security;

import java.util.Optional;

public interface RequestIdentityProvider {

    RequestIdentity requireIdentity();

    default RequestIdentity requireIdentityForAccountDeletion() {
        return requireIdentity();
    }

    Optional<RequestIdentity> currentIdentity();
}
