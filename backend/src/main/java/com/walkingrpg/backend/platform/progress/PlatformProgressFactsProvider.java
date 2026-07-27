package com.walkingrpg.backend.platform.progress;

public interface PlatformProgressFactsProvider {

    PlatformProgressFacts factsFor(String userId);
}
