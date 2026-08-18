package com.walkingrpg.backend.home.domain;

public record ExpeditionRouteNodeSnapshot(
        String nodeId,
        String nodeName,
        String state,
        ExpeditionRouteDecisionSnapshot decision
) {
    public ExpeditionRouteNodeSnapshot(
            String nodeId,
            String nodeName,
            String state
    ) {
        this(nodeId, nodeName, state, null);
    }
}
