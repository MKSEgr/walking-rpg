package com.walkingrpg.backend.operations;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import com.walkingrpg.backend.security.DevHeaderAuthenticationFilter;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalManagementPort;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "management.server.port=0"
)
@ActiveProfiles("test")
@Testcontainers
class OperationalEndpointsIntegrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer(
                    DockerImageName.parse(
                            "postgres@sha256:"
                                    + "742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"
                    ).asCompatibleSubstituteFor("postgres")
            );

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @LocalServerPort
    private int applicationPort;

    @LocalManagementPort
    private int managementPort;

    @Autowired
    private ApplicationContext applicationContext;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Test
    void shouldKeepProbeSemanticsAndMetricsBoundarySeparate() throws Exception {
        assertNotEquals(applicationPort, managementPort);
        assertTrue(
                applicationContext.getBean("dbHealthContributor")
                        instanceof BoundedDataSourceHealthIndicator
        );

        HttpResponse<String> mainLiveness = get(applicationPort, "/livez");
        HttpResponse<String> mainReadiness = get(applicationPort, "/readyz");
        assertHealth(mainLiveness);
        assertHealth(mainReadiness);

        HttpResponse<String> managementLiveness =
                get(managementPort, "/actuator/health/liveness");
        HttpResponse<String> managementReadiness =
                get(managementPort, "/actuator/health/readiness");
        assertHealth(managementLiveness);
        assertHealth(managementReadiness);

        HttpResponse<String> anonymousMetrics =
                get(managementPort, "/actuator/prometheus");
        assertEquals(401, anonymousMetrics.statusCode());
        assertEquals(
                "no-store",
                anonymousMetrics.headers()
                        .firstValue("Cache-Control")
                        .orElseThrow()
        );

        HttpRequest adminRequest = request(managementPort, "/actuator/prometheus")
                .header(DevHeaderAuthenticationFilter.USER_HEADER, "operations-admin")
                .header(
                        DevHeaderAuthenticationFilter.AUTHORITIES_HEADER,
                        "ADMIN"
                )
                .build();
        HttpResponse<String> adminMetrics = httpClient.send(
                adminRequest,
                HttpResponse.BodyHandlers.ofString()
        );
        assertEquals(200, adminMetrics.statusCode());
        assertTrue(adminMetrics.body().contains("jvm_memory_used_bytes"));
        assertTrue(adminMetrics.body().contains("http_server_requests"));
        assertTrue(adminMetrics.body().contains(
                "application=\"walking-rpg-backend\""
        ));

        assertEquals(401, get(managementPort, "/actuator").statusCode());
        HttpRequest undeclaredAdminRequest =
                request(managementPort, "/actuator/env")
                        .header(
                                DevHeaderAuthenticationFilter.USER_HEADER,
                                "operations-admin"
                        )
                        .header(
                                DevHeaderAuthenticationFilter.AUTHORITIES_HEADER,
                                "ADMIN"
                        )
                        .build();
        assertEquals(
                403,
                httpClient.send(
                        undeclaredAdminRequest,
                        HttpResponse.BodyHandlers.ofString()
                ).statusCode()
        );

        POSTGRES.stop();

        assertHealth(get(applicationPort, "/livez"));
        HttpResponse<String> unavailableReadiness =
                get(applicationPort, "/readyz");
        assertEquals(503, unavailableReadiness.statusCode());
        assertTrue(unavailableReadiness.body().contains("\"status\":\"DOWN\""));
        assertNoHealthDetails(unavailableReadiness);
    }

    private void assertHealth(HttpResponse<String> response) {
        assertEquals(200, response.statusCode());
        assertTrue(response.body().contains("\"status\":\"UP\""));
        assertNoHealthDetails(response);
    }

    private void assertNoHealthDetails(HttpResponse<String> response) {
        assertFalse(response.body().contains("\"components\""));
        assertFalse(response.body().contains("\"details\""));
    }

    private HttpResponse<String> get(int port, String path) throws Exception {
        return httpClient.send(
                request(port, path).build(),
                HttpResponse.BodyHandlers.ofString()
        );
    }

    private HttpRequest.Builder request(int port, String path) {
        return HttpRequest.newBuilder()
                .uri(URI.create("http://127.0.0.1:" + port + path))
                .timeout(Duration.ofSeconds(15))
                .GET();
    }
}
