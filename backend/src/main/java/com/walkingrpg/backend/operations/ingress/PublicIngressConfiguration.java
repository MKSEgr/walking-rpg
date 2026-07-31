package com.walkingrpg.backend.operations.ingress;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import tools.jackson.databind.ObjectMapper;

@Configuration(proxyBeanMethods = false)
public class PublicIngressConfiguration {

    @Bean
    PublicIngressRateLimiter publicIngressRateLimiter(
            PublicIngressProperties properties
    ) {
        return new PublicIngressRateLimiter(properties);
    }

    @Bean
    PublicIngressMetrics publicIngressMetrics(MeterRegistry meterRegistry) {
        return new PublicIngressMetrics(meterRegistry);
    }

    @Bean
    PublicIngressProtectionFilter publicIngressProtectionFilter(
            PublicIngressProperties properties,
            PublicIngressRateLimiter rateLimiter,
            PublicIngressMetrics metrics,
            ObjectMapper objectMapper
    ) {
        return new PublicIngressProtectionFilter(
                properties,
                rateLimiter,
                metrics,
                objectMapper
        );
    }

    @Bean
    FilterRegistrationBean<PublicIngressProtectionFilter>
            publicIngressProtectionFilterRegistration(
                    PublicIngressProtectionFilter filter
            ) {
        FilterRegistrationBean<PublicIngressProtectionFilter> registration =
                new FilterRegistrationBean<>(filter);
        registration.setName("publicIngressProtectionFilter");
        registration.addUrlPatterns("/*");
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 10);
        return registration;
    }
}
