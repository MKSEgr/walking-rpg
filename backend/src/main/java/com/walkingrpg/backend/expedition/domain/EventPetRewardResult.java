package com.walkingrpg.backend.expedition.domain;

public record EventPetRewardResult(
        String petId,
        String name,
        int level,
        int bondGained,
        int bond,
        long version
) {
}
