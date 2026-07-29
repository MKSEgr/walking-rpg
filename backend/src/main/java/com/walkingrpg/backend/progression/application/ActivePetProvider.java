package com.walkingrpg.backend.progression.application;

@FunctionalInterface
public interface ActivePetProvider {

    ActivePetSelection activePetFor(String userId);
}
