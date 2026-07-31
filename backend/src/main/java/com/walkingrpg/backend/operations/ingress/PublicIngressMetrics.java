package com.walkingrpg.backend.operations.ingress;

import io.micrometer.core.instrument.MeterRegistry;

final class PublicIngressMetrics {

    private static final String REQUESTS_METRIC =
            "walking_rpg_public_ingress_requests";
    private static final String BODY_METRIC =
            "walking_rpg_public_ingress_body_bytes";

    private final MeterRegistry meterRegistry;

    PublicIngressMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    void recordRequest(PublicIngressEndpoint endpoint, String outcome) {
        meterRegistry.counter(
                REQUESTS_METRIC,
                "endpoint",
                endpoint.metricTag(),
                "outcome",
                outcome
        ).increment();
    }

    void recordAcceptedBody(PublicIngressEndpoint endpoint, int bytes) {
        meterRegistry.summary(
                BODY_METRIC,
                "endpoint",
                endpoint.metricTag()
        ).record(bytes);
    }
}
