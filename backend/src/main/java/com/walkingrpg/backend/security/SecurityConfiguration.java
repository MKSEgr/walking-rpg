package com.walkingrpg.backend.security;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfiguration {

    @Bean
    FilterRegistrationBean<DevHeaderAuthenticationFilter> devHeaderFilterRegistration(
            DevHeaderAuthenticationFilter filter
    ) {
        FilterRegistrationBean<DevHeaderAuthenticationFilter> registration =
                new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    ActiveAccountFilter activeAccountFilter(
            RequestIdentityProvider identityProvider,
            JsonSecurityErrorWriter errorWriter
    ) {
        return new ActiveAccountFilter(identityProvider, errorWriter);
    }

    @Bean
    FilterRegistrationBean<ActiveAccountFilter> activeAccountFilterRegistration(
            ActiveAccountFilter filter
    ) {
        FilterRegistrationBean<ActiveAccountFilter> registration =
                new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            WalkingRpgSecurityProperties properties,
            DevHeaderAuthenticationFilter devHeaderAuthenticationFilter,
            ActiveAccountFilter activeAccountFilter,
            JwtAuthorityConverter jwtAuthorityConverter,
            JsonSecurityErrorWriter errorWriter
    ) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                )
                .requestCache(cache -> cache.disable())
                .formLogin(form -> form.disable())
                .httpBasic(basic -> basic.disable())
                .logout(logout -> logout.disable())
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(errorWriter)
                        .accessDeniedHandler(errorWriter)
                )
                .authorizeHttpRequests(authorize -> {
                    authorize.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();
                    authorize.requestMatchers(
                            HttpMethod.GET,
                            "/actuator/health",
                            "/actuator/health/**",
                            "/api/v1/system/info",
                            "/api/v1/content/bootstrap"
                    ).permitAll();
                    authorize.requestMatchers(
                            HttpMethod.POST,
                            "/api/v1/telemetry/events",
                            "/api/v1/diagnostics/crashes"
                    ).permitAll();
                    if (properties.isDemoEndpointsEnabled()) {
                        authorize.requestMatchers(HttpMethod.GET, "/api/v1/home/demo")
                                .permitAll();
                    }
                    authorize.requestMatchers("/api/v1/admin/**").hasRole("ADMIN");
                    authorize.requestMatchers("/api/v1/**").hasRole("USER");
                    authorize.requestMatchers("/error").permitAll();
                    authorize.anyRequest().denyAll();
                });

        if (properties.getMode() == WalkingRpgSecurityProperties.Mode.JWT) {
            http.oauth2ResourceServer(resourceServer -> resourceServer
                    .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthorityConverter))
                    .authenticationEntryPoint(errorWriter)
                    .accessDeniedHandler(errorWriter)
            );
            http.addFilterAfter(
                    activeAccountFilter,
                    BearerTokenAuthenticationFilter.class
            );
        } else {
            http.addFilterBefore(devHeaderAuthenticationFilter, AnonymousAuthenticationFilter.class);
            http.addFilterAfter(activeAccountFilter, DevHeaderAuthenticationFilter.class);
        }

        return http.build();
    }
}
