package com.walkingrpg.backend.operations.ingress;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Set;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import tools.jackson.databind.json.JsonMapper;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

class PublicIngressProtectionFilterTest {

    private PublicIngressProperties properties;
    private SimpleMeterRegistry meterRegistry;

    @BeforeEach
    void setUp() {
        properties = new PublicIngressProperties();
        properties.getTelemetry().setMaxBodyBytes(32);
        properties.getTelemetry().setClientBurstCapacity(10);
        properties.getTelemetry().setGlobalBurstCapacity(100);
        properties.getCrash().setMaxBodyBytes(64);
        properties.getCrash().setClientBurstCapacity(10);
        properties.getCrash().setGlobalBurstCapacity(100);
        meterRegistry = new SimpleMeterRegistry();
    }

    @Test
    void shouldPassBoundedBodyWithoutChangingPayload() throws Exception {
        PublicIngressProtectionFilter filter = filter();
        byte[] body = "{\"eventName\":\"walk\"}".getBytes(StandardCharsets.UTF_8);
        MockHttpServletRequest request = request(
                PublicIngressEndpoint.TELEMETRY.path(),
                body
        );
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertNotNull(chain.getRequest());
        assertArrayEquals(body, chain.getRequest().getInputStream().readAllBytes());
        assertEquals(
                1.0,
                meterRegistry.get("walking_rpg_public_ingress_requests")
                        .tag("endpoint", "telemetry")
                        .tag("outcome", "accepted")
                        .counter()
                        .count()
        );
    }

    @Test
    void shouldRejectDeclaredOversizedBodyWithoutCallingChain() throws Exception {
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletRequest request = request(
                PublicIngressEndpoint.TELEMETRY.path(),
                new byte[33]
        );
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(413, response.getStatus());
        assertEquals("no-store", response.getHeader(HttpHeaders.CACHE_CONTROL));
        assertNull(chain.getRequest());
        assertEquals(
                "PAYLOAD_TOO_LARGE",
                JsonMapper.builder().build()
                        .readTree(response.getContentAsByteArray())
                        .get("code")
                        .asText()
        );
    }

    @Test
    void shouldRejectChunkedBodyAfterReadingOnlyLimitPlusOne() throws Exception {
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletRequest request = new MockHttpServletRequest(
                "POST",
                PublicIngressEndpoint.TELEMETRY.path()
        ) {
            @Override
            public long getContentLengthLong() {
                return -1;
            }
        };
        request.setRemoteAddr("192.0.2.10");
        request.setContent(new byte[33]);
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(413, response.getStatus());
        assertNull(chain.getRequest());
    }

    @Test
    void shouldIgnoreForwardedAddressAndRateLimitSocketPeer() throws Exception {
        properties.getTelemetry().setClientBurstCapacity(1);
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletResponse firstResponse = new MockHttpServletResponse();
        MockHttpServletResponse secondResponse = new MockHttpServletResponse();
        MockHttpServletRequest first = request(
                PublicIngressEndpoint.TELEMETRY.path(),
                "{}".getBytes(StandardCharsets.UTF_8)
        );
        first.addHeader("X-Forwarded-For", "198.51.100.1");
        MockHttpServletRequest second = request(
                PublicIngressEndpoint.TELEMETRY.path(),
                "{}".getBytes(StandardCharsets.UTF_8)
        );
        second.addHeader("X-Forwarded-For", "198.51.100.2");

        filter.doFilter(first, firstResponse, new MockFilterChain());
        MockFilterChain secondChain = new MockFilterChain();
        filter.doFilter(second, secondResponse, secondChain);

        assertEquals(429, secondResponse.getStatus());
        assertEquals("1", secondResponse.getHeader(HttpHeaders.RETRY_AFTER));
        assertEquals("no-store", secondResponse.getHeader(HttpHeaders.CACHE_CONTROL));
        assertNull(secondChain.getRequest());
    }

    @Test
    void shouldNotExposeClientIdentityAsMetricTag() throws Exception {
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletRequest request = request(
                PublicIngressEndpoint.CRASH.path(),
                "{}".getBytes(StandardCharsets.UTF_8)
        );
        request.setRemoteAddr("203.0.113.77");

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                new MockFilterChain()
        );

        assertFalse(meterRegistry.getMeters().stream()
                .flatMap(meter -> meter.getId().getTags().stream())
                .anyMatch(tag -> Arrays.asList(
                        "203.0.113.77",
                        "client",
                        "client_id"
                ).contains(tag.getValue()) || tag.getKey().contains("client")));
    }

    @Test
    void shouldBypassNonIngressRequest() throws Exception {
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletRequest request = request("/api/v1/system/info", new byte[0]);
        request.setMethod("GET");
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                chain
        );

        assertNotNull(chain.getRequest());
        assertEquals(0, meterRegistry.getMeters().size());
    }

    @Test
    void shouldRegisterProtectionAcrossAllServletPaths() {
        PublicIngressConfiguration configuration =
                new PublicIngressConfiguration();

        assertEquals(
                Set.of("/*"),
                configuration.publicIngressProtectionFilterRegistration(
                        filter()
                ).getUrlPatterns()
        );
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "/api/v1/telemetry/events;source=matrix",
            "/api;v=1/v1/telemetry/events",
            "/api/v1/telemetry/%65vents"
    })
    void shouldProtectMvcEquivalentIngressPaths(String path) throws Exception {
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletRequest request = request(path, new byte[33]);
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertEquals(413, response.getStatus());
        assertNull(chain.getRequest());
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "/api/v1/telemetry/events/",
            "/api/v1/telemetry//events",
            "/api/v1/telemetry/../telemetry/events",
            "/api/v1/telemetry%2Fevents"
    })
    void shouldNotTreatNonMatchingPathsAsIngress(String path) throws Exception {
        PublicIngressProtectionFilter filter = filter();
        MockHttpServletRequest request = request(path, new byte[33]);
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                chain
        );

        assertNotNull(chain.getRequest());
        assertEquals(0, meterRegistry.getMeters().size());
    }

    private PublicIngressProtectionFilter filter() {
        return new PublicIngressProtectionFilter(
                properties,
                new PublicIngressRateLimiter(properties, () -> 0L),
                new PublicIngressMetrics(meterRegistry),
                JsonMapper.builder().build(),
                new byte[32]
        );
    }

    private MockHttpServletRequest request(String path, byte[] content) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", path);
        request.setRemoteAddr("192.0.2.10");
        request.setContent(content);
        request.setContentType("application/json");
        return request;
    }
}
