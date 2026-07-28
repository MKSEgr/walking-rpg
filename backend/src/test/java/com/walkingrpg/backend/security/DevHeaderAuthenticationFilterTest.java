package com.walkingrpg.backend.security;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DevHeaderAuthenticationFilterTest {

    private final DevHeaderAuthenticationFilter filter =
            new DevHeaderAuthenticationFilter();

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void shouldAuthenticateDevelopmentHeadersAndPromoteAdminToUser() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/home");
        request.addHeader(DevHeaderAuthenticationFilter.USER_HEADER, "dev-user");
        request.addHeader(DevHeaderAuthenticationFilter.DEVICE_HEADER, "device-1");
        request.addHeader(DevHeaderAuthenticationFilter.ACTOR_HEADER, "developer");
        request.addHeader(DevHeaderAuthenticationFilter.AUTHORITIES_HEADER, "ADMIN");

        filter.doFilter(request, new MockHttpServletResponse(), new MockFilterChain());

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        WalkingRpgPrincipal principal = (WalkingRpgPrincipal) authentication.getPrincipal();
        assertEquals("dev-user", principal.userId());
        assertEquals("developer", principal.actor());
        assertEquals("device-1", principal.deviceId());
        assertTrue(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("ROLE_ADMIN")));
        assertTrue(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("ROLE_USER")));
    }

    @Test
    void shouldLeaveRequestAnonymousWithoutDevelopmentUserHeader() throws Exception {
        filter.doFilter(
                new MockHttpServletRequest("GET", "/api/v1/home"),
                new MockHttpServletResponse(),
                new MockFilterChain()
        );

        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }
}
