package com.walkingrpg.backend.security;

import com.nimbusds.jose.proc.SecurityContext;
import com.nimbusds.jwt.proc.BadJWTException;
import com.nimbusds.jwt.proc.ConfigurableJWTProcessor;
import org.springframework.boot.security.oauth2.server.resource.autoconfigure.JwkSetUriJwtDecoderBuilderCustomizer;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

/**
 * Rejects a malformed OIDC subject before Spring's standard claim converter can
 * coerce its original JSON type to {@link String}.
 */
@Component
public final class ExactSubjectJwtDecoderCustomizer
        implements JwkSetUriJwtDecoderBuilderCustomizer {

    @Override
    public void customize(NimbusJwtDecoder.JwkSetUriJwtDecoderBuilder builder) {
        builder.jwtProcessorCustomizer(
                ExactSubjectJwtDecoderCustomizer::configureProcessor
        );
    }

    static void configureProcessor(
            ConfigurableJWTProcessor<SecurityContext> processor
    ) {
        processor.setJWTClaimsSetVerifier((claims, context) -> {
            Object subject = claims.getClaim("sub");
            if (!(subject instanceof String)) {
                throw new BadJWTException(
                        "JWT sub must be encoded as a JSON string"
                );
            }
        });
    }
}
