package com.walkingrpg.backend.security;

import java.time.Duration;

public class FreshAuthenticationRequiredException extends RuntimeException {

    private final Duration maxAuthenticationAge;

    public FreshAuthenticationRequiredException(
            String message,
            Duration maxAuthenticationAge
    ) {
        super(message);
        this.maxAuthenticationAge = maxAuthenticationAge;
    }

    public Duration maxAuthenticationAge() {
        return maxAuthenticationAge;
    }
}
