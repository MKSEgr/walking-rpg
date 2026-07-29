package com.walkingrpg.backend.shared.api;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.activity.application.ActivitySyncConflictException;
import com.walkingrpg.backend.activity.application.ActivitySyncValidationException;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.expedition.application.EventNotFoundException;
import com.walkingrpg.backend.expedition.application.EventResolutionIdempotencyConflictException;
import com.walkingrpg.backend.expedition.application.EventResolutionValidationException;
import com.walkingrpg.backend.expedition.application.EventResultReceiptNotFoundException;
import com.walkingrpg.backend.expedition.application.EventStateConflictException;
import com.walkingrpg.backend.expedition.application.ExpeditionIdempotencyConflictException;
import com.walkingrpg.backend.expedition.application.ExpeditionNotFoundException;
import com.walkingrpg.backend.expedition.application.ExpeditionStateConflictException;
import com.walkingrpg.backend.expedition.application.ExpeditionValidationException;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.home.application.HomeQueryValidationException;
import com.walkingrpg.backend.inventory.domain.InventoryLedgerConflictException;
import com.walkingrpg.backend.platform.application.PlatformIdempotencyConflictException;
import com.walkingrpg.backend.platform.application.PlatformStateConflictException;
import com.walkingrpg.backend.platform.application.PlatformValidationException;
import com.walkingrpg.backend.security.FreshAuthenticationRequiredException;
import com.walkingrpg.backend.security.MissingDeviceIdentityException;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException exception) {
        Map<String, Object> details = new LinkedHashMap<>();
        exception.getBindingResult().getFieldErrors().forEach(error ->
                details.putIfAbsent(error.getField(), error.getDefaultMessage())
        );
        return error(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_ERROR",
                "Запрос не прошёл валидацию",
                details
        );
    }

    @ExceptionHandler(ActivitySyncValidationException.class)
    ResponseEntity<ApiErrorResponse> handleActivityValidation(
            ActivitySyncValidationException exception
    ) {
        return fieldValidation(exception.getMessage(), exception.field());
    }

    @ExceptionHandler(HomeQueryValidationException.class)
    ResponseEntity<ApiErrorResponse> handleHomeValidation(
            HomeQueryValidationException exception
    ) {
        return fieldValidation(exception.getMessage(), exception.field());
    }

    @ExceptionHandler(ExpeditionValidationException.class)
    ResponseEntity<ApiErrorResponse> handleExpeditionValidation(
            ExpeditionValidationException exception
    ) {
        return fieldValidation(exception.getMessage(), exception.field());
    }

    @ExceptionHandler(EventResolutionValidationException.class)
    ResponseEntity<ApiErrorResponse> handleEventValidation(
            EventResolutionValidationException exception
    ) {
        return fieldValidation(exception.getMessage(), exception.field());
    }

    @ExceptionHandler(PlatformValidationException.class)
    ResponseEntity<ApiErrorResponse> handlePlatformValidation(
            PlatformValidationException exception
    ) {
        return fieldValidation(exception.getMessage(), exception.field());
    }

    @ExceptionHandler(ActivitySyncConflictException.class)
    ResponseEntity<ApiErrorResponse> handleActivityConflict(
            ActivitySyncConflictException exception
    ) {
        return idempotencyConflict(exception.getMessage());
    }

    @ExceptionHandler(ExpeditionIdempotencyConflictException.class)
    ResponseEntity<ApiErrorResponse> handleExpeditionIdempotencyConflict(
            ExpeditionIdempotencyConflictException exception
    ) {
        return idempotencyConflict(exception.getMessage());
    }

    @ExceptionHandler(EventResolutionIdempotencyConflictException.class)
    ResponseEntity<ApiErrorResponse> handleEventIdempotencyConflict(
            EventResolutionIdempotencyConflictException exception
    ) {
        return idempotencyConflict(exception.getMessage());
    }

    @ExceptionHandler(PlatformIdempotencyConflictException.class)
    ResponseEntity<ApiErrorResponse> handlePlatformIdempotencyConflict(
            PlatformIdempotencyConflictException exception
    ) {
        return idempotencyConflict(exception.getMessage());
    }

    @ExceptionHandler(ExpeditionNotFoundException.class)
    ResponseEntity<ApiErrorResponse> handleExpeditionNotFound(
            ExpeditionNotFoundException exception
    ) {
        return error(
                HttpStatus.NOT_FOUND,
                "NOT_FOUND",
                exception.getMessage(),
                Map.of("expeditionId", exception.expeditionId())
        );
    }

    @ExceptionHandler(EventNotFoundException.class)
    ResponseEntity<ApiErrorResponse> handleEventNotFound(
            EventNotFoundException exception
    ) {
        return error(
                HttpStatus.NOT_FOUND,
                "NOT_FOUND",
                exception.getMessage(),
                Map.of("eventId", exception.eventId())
        );
    }

    @ExceptionHandler(EventResultReceiptNotFoundException.class)
    ResponseEntity<ApiErrorResponse> handleEventResultNotFound(
            EventResultReceiptNotFoundException exception
    ) {
        return error(
                HttpStatus.NOT_FOUND,
                "EVENT_RESULT_NOT_FOUND",
                exception.getMessage(),
                Map.of("receiptId", exception.receiptId())
        );
    }

    @ExceptionHandler(PendingEventResultException.class)
    ResponseEntity<ApiErrorResponse> handlePendingEventResult(
            PendingEventResultException exception
    ) {
        return error(
                HttpStatus.CONFLICT,
                "EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED",
                exception.getMessage(),
                Map.of(
                        "receiptId", exception.receiptId(),
                        "eventId", exception.eventId()
                )
        );
    }

    @ExceptionHandler(ExpeditionStateConflictException.class)
    ResponseEntity<ApiErrorResponse> handleExpeditionStateConflict(
            ExpeditionStateConflictException exception
    ) {
        return error(
                HttpStatus.CONFLICT,
                "EXPEDITION_STATE_CONFLICT",
                exception.getMessage(),
                Map.of(
                        "status", exception.status().name(),
                        "remainingEnergy", exception.remainingEnergy()
                )
        );
    }

    @ExceptionHandler(EventStateConflictException.class)
    ResponseEntity<ApiErrorResponse> handleEventStateConflict(
            EventStateConflictException exception
    ) {
        return error(
                HttpStatus.CONFLICT,
                "EVENT_STATE_CONFLICT",
                exception.getMessage(),
                Map.of("status", exception.status())
        );
    }

    @ExceptionHandler(PlatformStateConflictException.class)
    ResponseEntity<ApiErrorResponse> handlePlatformStateConflict(
            PlatformStateConflictException exception
    ) {
        return error(
                HttpStatus.CONFLICT,
                "PLATFORM_STATE_CONFLICT",
                exception.getMessage(),
                exception.details()
        );
    }

    @ExceptionHandler(InsufficientEnergyException.class)
    ResponseEntity<ApiErrorResponse> handleInsufficientEnergy(
            InsufficientEnergyException exception
    ) {
        return error(
                HttpStatus.CONFLICT,
                "INSUFFICIENT_ENERGY",
                exception.getMessage(),
                Map.of(
                        "availableEnergy", exception.availableEnergy(),
                        "requiredEnergy", exception.requiredEnergy()
                )
        );
    }

    @ExceptionHandler(InventoryLedgerConflictException.class)
    ResponseEntity<ApiErrorResponse> handleInventoryLedgerConflict(
            InventoryLedgerConflictException exception
    ) {
        return error(
                HttpStatus.CONFLICT,
                "INVENTORY_LEDGER_CONFLICT",
                exception.getMessage(),
                Map.of()
        );
    }

    @ExceptionHandler({
            AuthenticationCredentialsNotFoundException.class,
            MissingDeviceIdentityException.class
    })
    ResponseEntity<ApiErrorResponse> handleAuthentication(RuntimeException exception) {
        return error(
                HttpStatus.UNAUTHORIZED,
                "AUTHENTICATION_ERROR",
                exception.getMessage(),
                Map.of()
        );
    }

    @ExceptionHandler(AccountDeletedException.class)
    ResponseEntity<ApiErrorResponse> handleDeletedAccount(
            AccountDeletedException exception
    ) {
        return error(
                HttpStatus.GONE,
                "ACCOUNT_DELETED",
                exception.getMessage(),
                Map.of()
        );
    }

    @ExceptionHandler(FreshAuthenticationRequiredException.class)
    ResponseEntity<ApiErrorResponse> handleFreshAuthenticationRequired(
            FreshAuthenticationRequiredException exception
    ) {
        return error(
                HttpStatus.FORBIDDEN,
                "FRESH_AUTHENTICATION_REQUIRED",
                exception.getMessage(),
                Map.of(
                        "maxAuthenticationAgeSeconds",
                        exception.maxAuthenticationAge().toSeconds()
                )
        );
    }

    @ExceptionHandler(MissingRequestHeaderException.class)
    ResponseEntity<ApiErrorResponse> handleMissingHeader(
            MissingRequestHeaderException exception
    ) {
        return error(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_ERROR",
                "Отсутствует обязательный заголовок",
                Map.of("field", exception.getHeaderName())
        );
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    ResponseEntity<ApiErrorResponse> handleMissingParameter(
            MissingServletRequestParameterException exception
    ) {
        return error(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_ERROR",
                "Отсутствует обязательный параметр запроса",
                Map.of("field", exception.getParameterName())
        );
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiErrorResponse> handleUnreadableBody(
            HttpMessageNotReadableException exception
    ) {
        return error(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_ERROR",
                "Тело запроса содержит некорректные данные",
                Map.of()
        );
    }

    private ResponseEntity<ApiErrorResponse> idempotencyConflict(String message) {
        return error(
                HttpStatus.CONFLICT,
                "IDEMPOTENCY_CONFLICT",
                message,
                Map.of("field", "idempotencyKey")
        );
    }

    private ResponseEntity<ApiErrorResponse> fieldValidation(
            String message,
            String field
    ) {
        return error(
                HttpStatus.BAD_REQUEST,
                "VALIDATION_ERROR",
                message,
                Map.of("field", field)
        );
    }

    private ResponseEntity<ApiErrorResponse> error(
            HttpStatus status,
            String code,
            String message,
            Map<String, Object> details
    ) {
        return ResponseEntity.status(status).body(
                new ApiErrorResponse(code, message, details, UUID.randomUUID())
        );
    }
}
