package com.walkingrpg.backend.security;

import java.util.Set;

public record RequestIdentity(
        String userId,
        String actor,
        String deviceId,
        Set<String> authorities
) {

    public RequestIdentity {
        authorities = Set.copyOf(authorities);
    }

    public String requireDeviceId() {
        if (deviceId == null || deviceId.isBlank()) {
            throw new MissingDeviceIdentityException();
        }
        return deviceId;
    }
}
