package com.walkingrpg.backend.security;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

class ActiveAccountFilterTest {

    private final RequestIdentityProvider identityProvider =
            mock(RequestIdentityProvider.class);
    private final JsonSecurityErrorWriter errorWriter =
            mock(JsonSecurityErrorWriter.class);
    private final ActiveAccountFilter filter =
            new ActiveAccountFilter(identityProvider, errorWriter);

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "/livez",
            "/readyz",
            "/actuator",
            "/actuator/health/liveness",
            "/actuator/health/readiness",
            "/actuator/prometheus",
            "/live%7a",
            "/readyz;v=1",
            "/actuator;v=1/prometheus",
            "/actuat%6fr/prometheus"
    })
    void shouldSkipAccountLookupForOperationsPaths(String path) throws Exception {
        authenticate();
        MockHttpServletRequest request = request("GET", path);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        verify(chain).doFilter(request, response);
        verifyNoInteractions(identityProvider, errorWriter);
    }

    @Test
    void shouldSkipOperationsPathBelowServletContext() throws Exception {
        authenticate();
        MockHttpServletRequest request = request(
                "GET",
                "/walking-rpg/actuator/prometheus"
        );
        request.setContextPath("/walking-rpg");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        verify(chain).doFilter(request, response);
        verifyNoInteractions(identityProvider, errorWriter);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "/livez/extra",
            "/readyz-status",
            "/actuatorish",
            "/api/v1/home"
    })
    void shouldKeepAccountLookupForNonOperationsLookalikes(String path)
            throws Exception {
        authenticate();
        MockHttpServletRequest request = request("GET", path);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        verify(identityProvider).requireIdentity();
        verify(chain).doFilter(request, response);
        verifyNoInteractions(errorWriter);
    }

    @Test
    void shouldPreserveDeletionReplayExclusionOnlyForPost() throws Exception {
        authenticate();
        MockHttpServletRequest post = request(
                "POST",
                "/api/v1/account/deletion-requests"
        );
        MockHttpServletResponse postResponse = new MockHttpServletResponse();
        FilterChain postChain = mock(FilterChain.class);

        filter.doFilter(post, postResponse, postChain);

        verify(postChain).doFilter(post, postResponse);
        verifyNoInteractions(identityProvider, errorWriter);

        MockHttpServletRequest get = request(
                "GET",
                "/api/v1/account/deletion-requests"
        );
        MockHttpServletResponse getResponse = new MockHttpServletResponse();
        FilterChain getChain = mock(FilterChain.class);

        filter.doFilter(get, getResponse, getChain);

        verify(identityProvider).requireIdentity();
        verify(getChain).doFilter(get, getResponse);
    }

    private void authenticate() {
        SecurityContextHolder.getContext().setAuthentication(
                new TestingAuthenticationToken("subject-123", null, "ROLE_USER")
        );
    }

    private MockHttpServletRequest request(String method, String path) {
        return new MockHttpServletRequest(method, path);
    }
}
