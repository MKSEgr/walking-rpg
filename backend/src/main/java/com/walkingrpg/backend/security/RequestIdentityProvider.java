package com.walkingrpg.backend.security;

import java.util.Optional;

public interface RequestIdentityProvider {

    RequestIdentity requireIdentity();

    Optional<RequestIdentity> currentIdentity();
}
