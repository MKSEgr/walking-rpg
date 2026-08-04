package com.walkingrpg.backend.security;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.stereotype.Component;

@Component
public class JwtAuthorityConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    private final WalkingRpgSecurityProperties properties;
    private final JwtGrantedAuthoritiesConverter scopeConverter =
            new JwtGrantedAuthoritiesConverter();

    public JwtAuthorityConverter(WalkingRpgSecurityProperties properties) {
        this.properties = properties;
    }

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        Set<String> authorities = new LinkedHashSet<>();
        Collection<GrantedAuthority> scopeAuthorities = scopeConverter.convert(jwt);
        if (scopeAuthorities != null) {
            scopeAuthorities.stream()
                    .map(GrantedAuthority::getAuthority)
                    .forEach(authorities::add);
        }

        Set<String> roles = stringValues(nestedClaim(jwt.getClaims(), properties.getRolesClaim()));
        Set<String> scopes = stringValues(jwt.getClaims().get("scope"));
        scopes.addAll(stringValues(jwt.getClaims().get("scp")));

        boolean admin = contains(roles, properties.getAdminRole())
                || contains(scopes, properties.getAdminScope());
        boolean user = admin
                || contains(roles, properties.getUserRole())
                || contains(scopes, properties.getUserScope());

        if (user) {
            authorities.add("ROLE_USER");
        }
        if (admin) {
            authorities.add("ROLE_ADMIN");
        }

        List<GrantedAuthority> grantedAuthorities = authorities.stream()
                .map(SimpleGrantedAuthority::new)
                .map(GrantedAuthority.class::cast)
                .toList();
        String subject = stringValue(jwt.getClaims().get("sub"));
        if (subject == null) {
            throw new OAuth2AuthenticationException(
                    new OAuth2Error("invalid_token"),
                    "JWT не содержит обязательный claim sub"
            );
        }
        String principalName = stringValue(
                nestedClaim(jwt.getClaims(), properties.getUsernameClaim())
        );
        return new JwtAuthenticationToken(
                jwt,
                grantedAuthorities,
                principalName == null ? subject : principalName
        );
    }

    private Object nestedClaim(Map<String, Object> claims, String claimPath) {
        if (claimPath == null || claimPath.isBlank()) {
            return null;
        }
        Object current = claims;
        for (String part : claimPath.split("\\.")) {
            if (!(current instanceof Map<?, ?> map)) {
                return null;
            }
            current = map.get(part);
        }
        return current;
    }

    private Set<String> stringValues(Object value) {
        Set<String> values = new LinkedHashSet<>();
        if (value instanceof String text) {
            for (String part : text.split("[,\\s]+")) {
                if (!part.isBlank()) {
                    values.add(part.trim());
                }
            }
        } else if (value instanceof Collection<?> collection) {
            for (Object item : collection) {
                String text = stringValue(item);
                if (text != null) {
                    values.add(text);
                }
            }
        }
        return values;
    }

    private boolean contains(Set<String> values, String expectedValue) {
        String normalizedExpected = normalize(expectedValue);
        if (normalizedExpected == null) {
            return false;
        }
        return values.stream()
                .map(this::normalize)
                .anyMatch(normalizedExpected::equals);
    }

    private String stringValue(Object value) {
        if (value instanceof String text && !text.isBlank()) {
            return text.trim();
        }
        return null;
    }

    private String normalize(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim().toUpperCase(Locale.ROOT).replace('-', '_');
    }
}
