package com.walkingrpg.backend.operations.ingress;

import org.springframework.http.server.PathContainer;
import org.springframework.web.util.pattern.PathPattern;
import org.springframework.web.util.pattern.PathPatternParser;

enum PublicIngressEndpoint {

    TELEMETRY("/api/v1/telemetry/events", "telemetry"),
    CRASH("/api/v1/diagnostics/crashes", "crash");

    private final String path;
    private final String metricTag;
    private final PathPattern pathPattern;

    PublicIngressEndpoint(String path, String metricTag) {
        this.path = path;
        this.metricTag = metricTag;
        this.pathPattern = PathPatternParser.defaultInstance.parse(path);
    }

    String path() {
        return path;
    }

    String metricTag() {
        return metricTag;
    }

    PublicIngressProperties.Endpoint policy(PublicIngressProperties properties) {
        return this == TELEMETRY ? properties.getTelemetry() : properties.getCrash();
    }

    static PublicIngressEndpoint fromPath(PathContainer path) {
        for (PublicIngressEndpoint endpoint : values()) {
            if (endpoint.pathPattern.matches(path)) {
                return endpoint;
            }
        }
        return null;
    }
}
