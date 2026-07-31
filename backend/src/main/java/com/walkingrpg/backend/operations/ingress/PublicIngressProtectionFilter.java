package com.walkingrpg.backend.operations.ingress;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

import com.walkingrpg.backend.shared.api.ApiErrorResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ServletRequestPathUtils;
import tools.jackson.databind.ObjectMapper;

final class PublicIngressProtectionFilter extends OncePerRequestFilter {

    private static final int CLIENT_HASH_SALT_BYTES = 32;

    private final PublicIngressProperties properties;
    private final PublicIngressRateLimiter rateLimiter;
    private final PublicIngressMetrics metrics;
    private final ObjectMapper objectMapper;
    private final byte[] clientHashSalt;

    PublicIngressProtectionFilter(
            PublicIngressProperties properties,
            PublicIngressRateLimiter rateLimiter,
            PublicIngressMetrics metrics,
            ObjectMapper objectMapper
    ) {
        this(
                properties,
                rateLimiter,
                metrics,
                objectMapper,
                randomSalt()
        );
    }

    PublicIngressProtectionFilter(
            PublicIngressProperties properties,
            PublicIngressRateLimiter rateLimiter,
            PublicIngressMetrics metrics,
            ObjectMapper objectMapper,
            byte[] clientHashSalt
    ) {
        this.properties = properties;
        this.rateLimiter = rateLimiter;
        this.metrics = metrics;
        this.objectMapper = objectMapper;
        this.clientHashSalt = clientHashSalt.clone();
        properties.validate();
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        PublicIngressEndpoint endpoint = endpoint(request);
        if (endpoint == null) {
            filterChain.doFilter(request, response);
            return;
        }

        PublicIngressRateLimiter.Decision decision = rateLimiter.acquire(
                endpoint,
                hashClient(request.getRemoteAddr())
        );
        if (!decision.allowed()) {
            metrics.recordRequest(
                    endpoint,
                    decision.rejection()
                            == PublicIngressRateLimiter.Rejection.GLOBAL
                            ? "rate_limited_global"
                            : "rate_limited_client"
            );
            response.setHeader(
                    HttpHeaders.RETRY_AFTER,
                    Long.toString(decision.retryAfterSeconds())
            );
            writeError(
                    response,
                    HttpStatus.TOO_MANY_REQUESTS.value(),
                    "RATE_LIMITED",
                    "Слишком много запросов; повторите попытку позже"
            );
            return;
        }

        int maxBodyBytes = endpoint.policy(properties).getMaxBodyBytes();
        long declaredLength = request.getContentLengthLong();
        if (declaredLength > maxBodyBytes) {
            rejectOversized(endpoint, response);
            return;
        }

        byte[] body = request.getInputStream().readNBytes(maxBodyBytes + 1);
        if (body.length > maxBodyBytes) {
            rejectOversized(endpoint, response);
            return;
        }

        metrics.recordRequest(endpoint, "accepted");
        metrics.recordAcceptedBody(endpoint, body.length);
        filterChain.doFilter(new BufferedRequest(request, body), response);
    }

    private void rejectOversized(
            PublicIngressEndpoint endpoint,
            HttpServletResponse response
    ) throws IOException {
        metrics.recordRequest(endpoint, "payload_too_large");
        writeError(
                response,
                HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE,
                "PAYLOAD_TOO_LARGE",
                "Тело запроса превышает допустимый размер"
        );
    }

    private void writeError(
            HttpServletResponse response,
            int status,
            String code,
            String message
    ) throws IOException {
        response.setStatus(status);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        objectMapper.writeValue(
                response.getOutputStream(),
                new ApiErrorResponse(code, message, Map.of(), UUID.randomUUID())
        );
    }

    private PublicIngressEndpoint endpoint(HttpServletRequest request) {
        if (!"POST".equals(request.getMethod())) {
            return null;
        }
        return PublicIngressEndpoint.fromPath(
                ServletRequestPathUtils.parseAndCache(request)
                        .pathWithinApplication()
        );
    }

    private String hashClient(String remoteAddress) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(clientHashSalt);
            digest.update((remoteAddress == null ? "" : remoteAddress)
                    .getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest.digest());
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }

    private static byte[] randomSalt() {
        byte[] salt = new byte[CLIENT_HASH_SALT_BYTES];
        new SecureRandom().nextBytes(salt);
        return salt;
    }

    private static final class BufferedRequest extends HttpServletRequestWrapper {

        private final byte[] body;

        private BufferedRequest(HttpServletRequest request, byte[] body) {
            super(request);
            this.body = body;
        }

        @Override
        public ServletInputStream getInputStream() {
            ByteArrayInputStream input = new ByteArrayInputStream(body);
            return new ServletInputStream() {

                @Override
                public int read() {
                    return input.read();
                }

                @Override
                public int read(byte[] bytes, int offset, int length) {
                    return input.read(bytes, offset, length);
                }

                @Override
                public boolean isFinished() {
                    return input.available() == 0;
                }

                @Override
                public boolean isReady() {
                    return true;
                }

                @Override
                public void setReadListener(ReadListener readListener) {
                    if (readListener == null) {
                        throw new IllegalArgumentException("readListener обязателен");
                    }
                    try {
                        if (isFinished()) {
                            readListener.onAllDataRead();
                        } else {
                            readListener.onDataAvailable();
                        }
                    } catch (IOException exception) {
                        readListener.onError(exception);
                    }
                }
            };
        }

        @Override
        public BufferedReader getReader() {
            String encoding = getCharacterEncoding();
            Charset charset = encoding == null
                    ? StandardCharsets.UTF_8
                    : Charset.forName(encoding);
            return new BufferedReader(new InputStreamReader(getInputStream(), charset));
        }
    }
}
