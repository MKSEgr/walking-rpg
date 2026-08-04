package com.walkingrpg.backend.security;

import java.text.ParseException;
import java.util.Map;

import com.nimbusds.jose.JWSObject;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;

/**
 * Preserves the JSON type of {@code sub} across the JWT decoding boundary.
 *
 * <p>Nimbus and Spring expose registered claims only after type conversion, so
 * the compact JWS payload is inspected before delegating signature and claims
 * validation to the configured decoder.</p>
 */
@Component
public final class ExactSubjectJwtDecoderBeanPostProcessor
        implements BeanPostProcessor {

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) {
        if (bean instanceof JwtDecoder decoder
                && !(bean instanceof ExactSubjectJwtDecoder)) {
            return new ExactSubjectJwtDecoder(decoder);
        }
        return bean;
    }

    private static final class ExactSubjectJwtDecoder implements JwtDecoder {

        private final JwtDecoder delegate;

        private ExactSubjectJwtDecoder(JwtDecoder delegate) {
            this.delegate = delegate;
        }

        @Override
        public Jwt decode(String token) {
            requireRawStringSubject(token);
            return delegate.decode(token);
        }

        private void requireRawStringSubject(String token) {
            Map<String, Object> claims;
            try {
                claims = JWSObject.parse(token).getPayload().toJSONObject();
            } catch (ParseException | IllegalArgumentException exception) {
                throw new BadJwtException(
                        "JWT payload must be a JSON object",
                        exception
                );
            }
            if (claims == null || !(claims.get("sub") instanceof String)) {
                throw new BadJwtException(
                        "JWT sub must be encoded as a JSON string"
                );
            }
        }
    }
}
