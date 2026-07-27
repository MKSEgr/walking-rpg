package com.walkingrpg.backend.platform.domain;

import java.util.List;

public record SquadView(
        String squadId,
        String name,
        String ownerUserId,
        List<String> memberUserIds
) {
    public SquadView {
        memberUserIds = memberUserIds == null ? List.of() : List.copyOf(memberUserIds);
    }
}
