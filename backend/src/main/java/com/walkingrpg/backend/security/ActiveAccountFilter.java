package com.walkingrpg.backend.security;

import java.io.IOException;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpMethod;
import org.springframework.http.server.PathContainer;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ServletRequestPathUtils;
import org.springframework.web.util.pattern.PathPattern;
import org.springframework.web.util.pattern.PathPatternParser;

public class ActiveAccountFilter extends OncePerRequestFilter {

    private static final String ACCOUNT_DELETION_PATH =
            "/api/v1/account/deletion-requests";
    private static final PathPattern LIVE_PATH =
            pattern("/livez");
    private static final PathPattern READY_PATH =
            pattern("/readyz");
    private static final PathPattern ACTUATOR_ROOT_PATH =
            pattern("/actuator");
    private static final PathPattern ACTUATOR_SUBPATH =
            pattern("/actuator/**");
    private static final PathPattern ACCOUNT_DELETION_REQUEST_PATH =
            pattern(ACCOUNT_DELETION_PATH);

    private final RequestIdentityProvider identityProvider;
    private final JsonSecurityErrorWriter errorWriter;

    public ActiveAccountFilter(
            RequestIdentityProvider identityProvider,
            JsonSecurityErrorWriter errorWriter
    ) {
        this.identityProvider = identityProvider;
        this.errorWriter = errorWriter;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        Authentication authentication =
                SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null
                && authentication.isAuthenticated()
                && !(authentication instanceof AnonymousAuthenticationToken)) {
            try {
                if (isActuatorRequest(request)) {
                    identityProvider.requireValidatedIdentity();
                } else {
                    identityProvider.requireIdentity();
                }
            } catch (AccountDeletedException exception) {
                SecurityContextHolder.clearContext();
                errorWriter.writeAccountDeleted(response, exception);
                return;
            } catch (AuthenticationException exception) {
                SecurityContextHolder.clearContext();
                errorWriter.commence(request, response, exception);
                return;
            }
        }
        filterChain.doFilter(request, response);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        PathContainer path = ServletRequestPathUtils.parseAndCache(request)
                .pathWithinApplication();
        if (LIVE_PATH.matches(path)
                || READY_PATH.matches(path)) {
            return true;
        }
        return HttpMethod.POST.matches(request.getMethod())
                && ACCOUNT_DELETION_REQUEST_PATH.matches(path);
    }

    private boolean isActuatorRequest(HttpServletRequest request) {
        PathContainer path = ServletRequestPathUtils.parseAndCache(request)
                .pathWithinApplication();
        return ACTUATOR_ROOT_PATH.matches(path)
                || ACTUATOR_SUBPATH.matches(path);
    }

    private static PathPattern pattern(String path) {
        return PathPatternParser.defaultInstance.parse(path);
    }
}
