package com.walkingrpg.backend.security;

import java.time.Clock;
import java.util.Map;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import tools.jackson.databind.ObjectMapper;

import static org.hamcrest.Matchers.hasLength;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.reset;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(SpringExtension.class)
@WebAppConfiguration
@ContextConfiguration(classes = {
        SecurityConfiguration.class,
        JwtSecurityIntegrationTest.TestConfiguration.class
})
class JwtSecurityIntegrationTest {

    @Autowired
    private WebApplicationContext applicationContext;

    @Autowired
    private FilterRegistrationBean<DevHeaderAuthenticationFilter> devHeaderFilterRegistration;

    @Autowired
    private FilterRegistrationBean<ActiveAccountFilter> activeAccountFilterRegistration;

    @Autowired
    private AccountDeletionRegistry accountDeletionRegistry;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        reset(accountDeletionRegistry);
        mockMvc = MockMvcBuilders.webAppContextSetup(applicationContext)
                .apply(springSecurity())
                .build();
    }

    @Test
    void shouldDisableServletContainerRegistrationOfDevHeaderFilter() {
        assertFalse(devHeaderFilterRegistration.isEnabled());
        assertFalse(activeAccountFilterRegistration.isEnabled());
    }

    @Test
    void shouldIgnoreDevelopmentIdentityHeadersInJwtMode() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe")
                        .header(DevHeaderAuthenticationFilter.USER_HEADER, "forged-user")
                        .header(DevHeaderAuthenticationFilter.AUTHORITIES_HEADER, "ADMIN"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("WWW-Authenticate", "Bearer"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));
    }

    @Test
    void shouldRequireApplicationUserAuthority() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe")
                        .with(jwt().jwt(token -> token.subject("user-1"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void shouldUseJwtSubjectActorAndStableDeviceClaim() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe")
                        .with(jwt()
                                .jwt(token -> token
                                        .issuer("https://identity.example.com")
                                        .subject("subject-123")
                                        .claim("preferred_username", "walker")
                                        .claim("device_id", "installation-9"))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value("subject-123"))
                .andExpect(jsonPath("$.actor").value("walker"))
                .andExpect(jsonPath("$.deviceId", hasLength(64)));
    }

    @Test
    void shouldRejectUserAuthorityFromAdminApi() throws Exception {
        mockMvc.perform(get("/api/v1/admin/security/probe")
                        .with(jwt()
                                .jwt(token -> token.subject("user-1"))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void shouldAllowAdminAuthorityAndDeriveActorFromJwt() throws Exception {
        mockMvc.perform(get("/api/v1/admin/security/probe")
                        .with(jwt()
                                .jwt(token -> token
                                        .subject("admin-subject")
                                        .claim("preferred_username", "release-operator"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_USER"),
                                        new SimpleGrantedAuthority("ROLE_ADMIN")
                                )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value("admin-subject"))
                .andExpect(jsonPath("$.actor").value("release-operator"));
    }

    @Test
    void shouldRejectDeletedAdminBeforeControllerWithoutIdentityLookup() throws Exception {
        doThrow(new AccountDeletedException())
                .when(accountDeletionRegistry)
                .requireActive("deleted-admin");

        mockMvc.perform(get("/api/v1/admin/security/raw-probe")
                        .with(jwt()
                                .jwt(token -> token.subject("deleted-admin"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_USER"),
                                        new SimpleGrantedAuthority("ROLE_ADMIN")
                                )))
                .andExpect(status().isGone())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("ACCOUNT_DELETED"));
    }

    @Test
    void shouldAllowDeletedSubjectToReplayDeletionReceipt() throws Exception {
        doThrow(new AccountDeletedException())
                .when(accountDeletionRegistry)
                .requireActive("deleted-user");

        mockMvc.perform(post("/api/v1/account/deletion-requests")
                        .with(jwt()
                                .jwt(token -> token.subject("deleted-user"))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.replayed").value(true));
    }

    @Test
    void shouldKeepContentBootstrapPublicInJwtMode() throws Exception {
        mockMvc.perform(get("/api/v1/content/bootstrap"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.public").value(true));
    }

    @Configuration
    @EnableWebMvc
    static class TestConfiguration {

        @Bean
        WalkingRpgSecurityProperties walkingRpgSecurityProperties() {
            WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
            properties.setMode(WalkingRpgSecurityProperties.Mode.JWT);
            properties.setDemoEndpointsEnabled(false);
            return properties;
        }

        @Bean
        DevHeaderAuthenticationFilter devHeaderAuthenticationFilter() {
            return new DevHeaderAuthenticationFilter();
        }

        @Bean
        JwtAuthorityConverter jwtAuthorityConverter(
                WalkingRpgSecurityProperties properties
        ) {
            return new JwtAuthorityConverter(properties);
        }

        @Bean
        RequestIdentityProvider requestIdentityProvider(
                WalkingRpgSecurityProperties properties,
                AccountDeletionRegistry accountDeletionRegistry
        ) {
            return new SecurityContextRequestIdentityProvider(
                    properties,
                    accountDeletionRegistry,
                    Clock.systemUTC()
            );
        }

        @Bean
        AccountDeletionRegistry accountDeletionRegistry() {
            return mock(AccountDeletionRegistry.class);
        }

        @Bean
        JsonSecurityErrorWriter jsonSecurityErrorWriter(ObjectMapper objectMapper) {
            return new JsonSecurityErrorWriter(objectMapper);
        }

        @Bean
        ObjectMapper objectMapper() {
            return new ObjectMapper();
        }

        @Bean
        JwtDecoder jwtDecoder() {
            return token -> {
                throw new IllegalStateException("JWT decoder is not used by mock JWT requests");
            };
        }

        @Bean
        SecurityProbeController securityProbeController(
                RequestIdentityProvider identityProvider
        ) {
            return new SecurityProbeController(identityProvider);
        }
    }

    @RestController
    static class SecurityProbeController {

        private final RequestIdentityProvider identityProvider;

        SecurityProbeController(RequestIdentityProvider identityProvider) {
            this.identityProvider = identityProvider;
        }

        @GetMapping("/api/v1/security/probe")
        Map<String, Object> userProbe() {
            RequestIdentity identity = identityProvider.requireIdentity();
            return Map.of(
                    "userId", identity.userId(),
                    "actor", identity.actor(),
                    "deviceId", identity.deviceId() == null ? "" : identity.deviceId()
            );
        }

        @GetMapping("/api/v1/admin/security/probe")
        Map<String, Object> adminProbe() {
            RequestIdentity identity = identityProvider.requireIdentity();
            return Map.of("userId", identity.userId(), "actor", identity.actor());
        }

        @GetMapping("/api/v1/admin/security/raw-probe")
        Map<String, Object> rawAdminProbe() {
            return Map.of("admin", true);
        }

        @org.springframework.web.bind.annotation.PostMapping(
                "/api/v1/account/deletion-requests"
        )
        Map<String, Object> replayDeletionReceipt() {
            return Map.of("replayed", true);
        }

        @GetMapping("/api/v1/content/bootstrap")
        Map<String, Object> publicContent() {
            return Map.of("public", true);
        }
    }
}
