package com.walkingrpg.backend.operations.ingress;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("walking-rpg.operations.public-ingress")
public class PublicIngressProperties {

    private static final int MAX_CONFIGURED_BODY_BYTES = 1_048_576;

    private int maxTrackedClients = 10_000;
    private Duration clientIdleTtl = Duration.ofMinutes(10);
    private Endpoint telemetry = Endpoint.telemetryDefaults();
    private Endpoint crash = Endpoint.crashDefaults();

    public int getMaxTrackedClients() {
        return maxTrackedClients;
    }

    public void setMaxTrackedClients(int maxTrackedClients) {
        this.maxTrackedClients = maxTrackedClients;
    }

    public Duration getClientIdleTtl() {
        return clientIdleTtl;
    }

    public void setClientIdleTtl(Duration clientIdleTtl) {
        this.clientIdleTtl = clientIdleTtl;
    }

    public Endpoint getTelemetry() {
        return telemetry;
    }

    public void setTelemetry(Endpoint telemetry) {
        this.telemetry = telemetry;
    }

    public Endpoint getCrash() {
        return crash;
    }

    public void setCrash(Endpoint crash) {
        this.crash = crash;
    }

    public void validate() {
        if (maxTrackedClients <= 0) {
            throw invalid("max-tracked-clients должен быть положительным");
        }
        if (clientIdleTtl == null
                || clientIdleTtl.isZero()
                || clientIdleTtl.isNegative()) {
            throw invalid("client-idle-ttl должен быть положительным");
        }
        if (telemetry == null || crash == null) {
            throw invalid("telemetry и crash policies обязательны");
        }
        telemetry.validate("telemetry");
        crash.validate("crash");
    }

    private static IllegalArgumentException invalid(String message) {
        return new IllegalArgumentException(
                "Некорректная walking-rpg.operations.public-ingress: " + message
        );
    }

    public static class Endpoint {

        private int maxBodyBytes;
        private int clientRequestsPerMinute;
        private int clientBurstCapacity;
        private int globalRequestsPerMinute;
        private int globalBurstCapacity;

        static Endpoint telemetryDefaults() {
            return defaults(16_384, 60, 20, 6_000, 1_000);
        }

        static Endpoint crashDefaults() {
            return defaults(65_536, 6, 3, 600, 100);
        }

        private static Endpoint defaults(
                int maxBodyBytes,
                int clientRequestsPerMinute,
                int clientBurstCapacity,
                int globalRequestsPerMinute,
                int globalBurstCapacity
        ) {
            Endpoint endpoint = new Endpoint();
            endpoint.maxBodyBytes = maxBodyBytes;
            endpoint.clientRequestsPerMinute = clientRequestsPerMinute;
            endpoint.clientBurstCapacity = clientBurstCapacity;
            endpoint.globalRequestsPerMinute = globalRequestsPerMinute;
            endpoint.globalBurstCapacity = globalBurstCapacity;
            return endpoint;
        }

        public int getMaxBodyBytes() {
            return maxBodyBytes;
        }

        public void setMaxBodyBytes(int maxBodyBytes) {
            this.maxBodyBytes = maxBodyBytes;
        }

        public int getClientRequestsPerMinute() {
            return clientRequestsPerMinute;
        }

        public void setClientRequestsPerMinute(int clientRequestsPerMinute) {
            this.clientRequestsPerMinute = clientRequestsPerMinute;
        }

        public int getClientBurstCapacity() {
            return clientBurstCapacity;
        }

        public void setClientBurstCapacity(int clientBurstCapacity) {
            this.clientBurstCapacity = clientBurstCapacity;
        }

        public int getGlobalRequestsPerMinute() {
            return globalRequestsPerMinute;
        }

        public void setGlobalRequestsPerMinute(int globalRequestsPerMinute) {
            this.globalRequestsPerMinute = globalRequestsPerMinute;
        }

        public int getGlobalBurstCapacity() {
            return globalBurstCapacity;
        }

        public void setGlobalBurstCapacity(int globalBurstCapacity) {
            this.globalBurstCapacity = globalBurstCapacity;
        }

        private void validate(String name) {
            if (maxBodyBytes <= 0 || maxBodyBytes > MAX_CONFIGURED_BODY_BYTES) {
                throw invalid(
                        name + ".max-body-bytes должен быть в диапазоне 1..1048576"
                );
            }
            if (clientRequestsPerMinute <= 0 || clientBurstCapacity <= 0) {
                throw invalid(name + " client rate/burst должны быть положительными");
            }
            if (globalRequestsPerMinute <= 0 || globalBurstCapacity <= 0) {
                throw invalid(name + " global rate/burst должны быть положительными");
            }
        }
    }
}
