package com.walkingrpg.backend.security;

import java.io.IOException;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

public class ActiveAccountFilter extends OncePerRequestFilter {

    private static final String ACCOUNT_DELETION_PATH =
            "/api/v1/account/deletion-requests";

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
                identityProvider.requireIdentity();
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
        if (!HttpMethod.POST.matches(request.getMethod())) {
            return false;
        }
        String requestUri = request.getRequestURI();
        String contextPath = request.getContextPath();
        String path = contextPath.isEmpty()
                ? requestUri
                : requestUri.substring(contextPath.length());
        return ACCOUNT_DELETION_PATH.equals(path);
    }
}
