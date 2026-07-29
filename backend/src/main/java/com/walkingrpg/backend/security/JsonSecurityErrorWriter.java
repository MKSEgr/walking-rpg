package com.walkingrpg.backend.security;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.shared.api.ApiErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

@Component
public class JsonSecurityErrorWriter implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    public JsonSecurityErrorWriter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException
    ) throws IOException {
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        write(
                response,
                HttpServletResponse.SC_UNAUTHORIZED,
                "AUTHENTICATION_ERROR",
                "Требуется действующий access token"
        );
    }

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException accessDeniedException
    ) throws IOException {
        write(
                response,
                HttpServletResponse.SC_FORBIDDEN,
                "FORBIDDEN",
                "Недостаточно прав для выполнения операции"
        );
    }

    public void writeAccountDeleted(
            HttpServletResponse response,
            AccountDeletedException exception
    ) throws IOException {
        write(
                response,
                HttpServletResponse.SC_GONE,
                "ACCOUNT_DELETED",
                exception.getMessage()
        );
    }

    private void write(
            HttpServletResponse response,
            int status,
            String code,
            String message
    ) throws IOException {
        response.setStatus(status);
        response.setCharacterEncoding(java.nio.charset.StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        ApiErrorResponse error = new ApiErrorResponse(
                code,
                message,
                Map.of(),
                UUID.randomUUID()
        );
        objectMapper.writeValue(response.getOutputStream(), error);
    }
}
