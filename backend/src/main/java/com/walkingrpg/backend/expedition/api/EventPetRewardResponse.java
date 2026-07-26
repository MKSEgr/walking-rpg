package com.walkingrpg.backend.expedition.api;

public record EventPetRewardResponse(
        String petId,
        String name,
        int level,
        int bondGained,
        int bond,
        long version
) {
}
