package com.walkingrpg.backend.security;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.JWSObject;
import com.nimbusds.jose.Payload;
import com.nimbusds.jose.crypto.MACSigner;
import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
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
import static org.mockito.Mockito.verifyNoInteractions;
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
        ExactSubjectJwtDecoderBeanPostProcessor.class,
        JwtSecurityIntegrationTest.TestConfiguration.class
})
class JwtSecurityIntegrationTest {

    private static final byte[] TEST_JWT_SECRET =
            "0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.US_ASCII);

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
    void shouldRejectAmbiguousSignedIdentityBeforeController() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe")
                        .with(jwt()
                                .jwt(token -> token
                                        .issuer("https://identity.example.com")
                                        .subject(" subject-123"))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));
    }

    @Test
    void shouldRejectMalformedOptionalIdentityClaimBeforeController() throws Exception {
        mockMvc.perform(get("/api/v1/security/probe")
                        .with(jwt()
                                .jwt(token -> token
                                        .issuer("https://identity.example.com")
                                        .subject("subject-123")
                                        .claim("preferred_username", 42))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));

        mockMvc.perform(get("/api/v1/security/probe")
                        .with(jwt()
                                .jwt(token -> token
                                        .issuer("https://identity.example.com")
                                        .subject("subject-123")
                                        .claim("device_id", ""))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));
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

    @Test
    void shouldKeepMainPortProbeAliasesPublic() throws Exception {
        mockMvc.perform(get("/livez"))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/readyz"))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldProtectPrometheusWithAdminAuthority() throws Exception {
        mockMvc.perform(get("/actuator/prometheus"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/actuator/prometheus")
                        .with(jwt()
                                .jwt(token -> token.subject("user-1"))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/actuator/prometheus")
                        .with(jwt()
                                .jwt(token -> token.subject("admin-1"))
                                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
                .andExpect(status().isNotFound());

        verifyNoInteractions(accountDeletionRegistry);
    }

    @Test
    void shouldRejectMalformedIdentityClaimsFromProtectedPrometheus() throws Exception {
        mockMvc.perform(get("/actuator/prometheus")
                        .with(jwt()
                                .jwt(token -> token.claim("sub", 42))
                                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));

        mockMvc.perform(get("/actuator/prometheus")
                        .with(jwt()
                                .jwt(token -> token
                                        .subject("admin-1")
                                        .claim("preferred_username", 42))
                                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));

        mockMvc.perform(get("/actuator/prometheus")
                        .with(jwt()
                                .jwt(token -> token
                                        .subject("admin-1")
                                        .claim("device_id", ""))
                                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));

        verifyNoInteractions(accountDeletionRegistry);
    }

    @Test
    void shouldRejectSignedNumericSubjectBeforeClaimSetConversion() throws Exception {
        mockMvc.perform(get("/actuator/prometheus")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + signedAdminToken(42)
                        ))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));

        mockMvc.perform(get("/actuator/prometheus")
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + signedAdminToken("42")
                        ))
                .andExpect(status().isNotFound());

        verifyNoInteractions(accountDeletionRegistry);
    }

    @Test
    void shouldDenyUndeclaredActuatorSurface() throws Exception {
        mockMvc.perform(get("/actuator"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/actuator/env")
                        .with(jwt()
                                .jwt(token -> token.subject("admin-1"))
                                .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
                .andExpect(status().isForbidden());
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
            SecretKey key = new SecretKeySpec(TEST_JWT_SECRET, "HmacSHA256");
            return NimbusJwtDecoder.withSecretKey(key)
                    .macAlgorithm(MacAlgorithm.HS256)
                    .build();
        }

        @Bean
        SecurityProbeController securityProbeController(
                RequestIdentityProvider identityProvider
        ) {
            return new SecurityProbeController(identityProvider);
        }
    }

    private String signedAdminToken(Object subject) throws JOSEException {
        Instant now = Instant.now();
        Map<String, Object> claims = Map.of(
                "sub", subject,
                "roles", List.of("walking-rpg-admin"),
                "iat", now.minusSeconds(5).getEpochSecond(),
                "exp", now.plusSeconds(300).getEpochSecond()
        );
        JWSObject token = new JWSObject(
                new JWSHeader(JWSAlgorithm.HS256),
                new Payload(claims)
        );
        token.sign(new MACSigner(TEST_JWT_SECRET));
        return token.serialize();
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
