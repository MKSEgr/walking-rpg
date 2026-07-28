package com.walkingrpg.backend.security;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class DevHeaderAuthenticationFilter extends OncePerRequestFilter {

    public static final String USER_HEADER = "X-User-Id";
    public static final String DEVICE_HEADER = "X-Device-Id";
    public static final String ACTOR_HEADER = "X-Mock-User";
    public static final String AUTHORITIES_HEADER = "X-Mock-Authorities";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            String userId = normalize(request.getHeader(USER_HEADER));
            if (userId != null) {
                String actor = normalize(request.getHeader(ACTOR_HEADER));
                String deviceId = normalize(request.getHeader(DEVICE_HEADER));
                Collection<GrantedAuthority> authorities = parseAuthorities(
                        request.getHeader(AUTHORITIES_HEADER)
                );
                WalkingRpgPrincipal principal = new WalkingRpgPrincipal(
                        userId,
                        actor == null ? userId : actor,
                        deviceId
                );
                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(principal, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        }
        filterChain.doFilter(request, response);
    }

    private Collection<GrantedAuthority> parseAuthorities(String raw) {
        Set<String> normalized = new LinkedHashSet<>();
        if (raw != null) {
            for (String token : raw.split("[,\\s]+")) {
                String authority = normalizeAuthority(token);
                if (authority != null) {
                    normalized.add(authority);
                }
            }
        }
        if (normalized.isEmpty()) {
            normalized.add("ROLE_USER");
        }
        if (normalized.contains("ROLE_ADMIN")) {
            normalized.add("ROLE_USER");
        }
        List<GrantedAuthority> authorities = new ArrayList<>();
        normalized.forEach(value -> authorities.add(new SimpleGrantedAuthority(value)));
        return List.copyOf(authorities);
    }

    private String normalizeAuthority(String value) {
        String normalized = normalize(value);
        if (normalized == null) {
            return null;
        }
        String upper = normalized.toUpperCase(Locale.ROOT).replace('-', '_');
        return upper.startsWith("ROLE_") ? upper : "ROLE_" + upper;
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }
}
