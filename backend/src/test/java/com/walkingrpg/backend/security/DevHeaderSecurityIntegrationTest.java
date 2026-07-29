package com.walkingrpg.backend.security;

import java.time.Clock;
import java.util.Map;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
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

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.reset;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(SpringExtension.class)
@WebAppConfiguration
@ContextConfiguration(classes = {
        SecurityConfiguration.class,
        DevHeaderSecurityIntegrationTest.TestConfiguration.class
})
class DevHeaderSecurityIntegrationTest {

    @Autowired
    private WebApplicationContext applicationContext;

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
    void shouldRequireDevelopmentIdentityForUserApi() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void shouldAuthenticateDevelopmentHeadersAsUser() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe")
                        .header(DevHeaderAuthenticationFilter.USER_HEADER, "dev-user")
                        .header(DevHeaderAuthenticationFilter.DEVICE_HEADER, "device-7"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value("dev-user"))
                .andExpect(jsonPath("$.actor").value("dev-user"))
                .andExpect(jsonPath("$.deviceId").value("device-7"));
    }

    @Test
    void shouldRejectNormalUserFromAdminApi() throws Exception {
        mockMvc.perform(get("/api/v1/admin/security/probe")
                        .header(DevHeaderAuthenticationFilter.USER_HEADER, "dev-user"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    void shouldAllowDevelopmentAdminAndUseActorHeader() throws Exception {
        mockMvc.perform(get("/api/v1/admin/security/probe")
                        .header(DevHeaderAuthenticationFilter.USER_HEADER, "admin-subject")
                        .header(DevHeaderAuthenticationFilter.ACTOR_HEADER, "local-operator")
                        .header(DevHeaderAuthenticationFilter.AUTHORITIES_HEADER, "ADMIN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value("admin-subject"))
                .andExpect(jsonPath("$.actor").value("local-operator"));
    }

    @Test
    void shouldRejectDeletedDevelopmentAdminBeforeController() throws Exception {
        doThrow(new AccountDeletedException())
                .when(accountDeletionRegistry)
                .requireActive("deleted-admin");

        mockMvc.perform(get("/api/v1/admin/security/raw-probe")
                        .header(DevHeaderAuthenticationFilter.USER_HEADER, "deleted-admin")
                        .header(DevHeaderAuthenticationFilter.AUTHORITIES_HEADER, "ADMIN"))
                .andExpect(status().isGone())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DELETED"));
    }

    @Test
    void shouldKeepExplicitPublicEndpointsAnonymous() throws Exception {
        mockMvc.perform(get("/api/v1/content/bootstrap"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.public").value(true));
        mockMvc.perform(get("/api/v1/home/demo"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.demo").value(true));
    }

    @Configuration
    @EnableWebMvc
    static class TestConfiguration {

        @Bean
        WalkingRpgSecurityProperties walkingRpgSecurityProperties() {
            WalkingRpgSecurityProperties properties = new WalkingRpgSecurityProperties();
            properties.setMode(WalkingRpgSecurityProperties.Mode.DEV_HEADER);
            properties.setDemoEndpointsEnabled(true);
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

        @GetMapping("/api/v1/content/bootstrap")
        Map<String, Object> publicContent() {
            return Map.of("public", true);
        }

        @GetMapping("/api/v1/home/demo")
        Map<String, Object> demo() {
            return Map.of("demo", true);
        }
    }
}
