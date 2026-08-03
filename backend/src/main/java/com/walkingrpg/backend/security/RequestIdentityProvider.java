package com.walkingrpg.backend.security;

import java.util.Optional;

public interface RequestIdentityProvider {

    /**
     * Resolves and validates authenticated identity claims without consulting
     * application account state.
     */
    RequestIdentity requireValidatedIdentity();

    RequestIdentity requireIdentity();

    default RequestIdentity requireIdentityForAccountDeletion() {
        return requireIdentity();
    }

    Optional<RequestIdentity> currentIdentity();
}
