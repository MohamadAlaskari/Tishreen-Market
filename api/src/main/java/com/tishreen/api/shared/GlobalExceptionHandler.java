package com.tishreen.api.shared;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Maps every exception to the single ApiError shape (docs/06 §Errors, docs/09 §Error handling).
 * Stack traces are logged with the correlation id, never returned to the client.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private final MessageSource messages;

    public GlobalExceptionHandler(MessageSource messages) {
        this.messages = messages;
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiError> businessRule(BusinessException ex) {
        return respond(ex.status(), ex.code(), ex.args(), ex.details());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> validation(MethodArgumentNotValidException ex) {
        List<Map<String, Object>> fields = ex.getBindingResult().getFieldErrors().stream()
                .<Map<String, Object>>map(e -> Map.of("field", e.getField(), "code", String.valueOf(e.getCode())))
                .toList();
        return respond(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", null, Map.of("fields", fields));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiError> malformedBody(HttpMessageNotReadableException ex) {
        return respond(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", null, null);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiError> methodNotSupported(HttpRequestMethodNotSupportedException ex) {
        return respond(HttpStatus.METHOD_NOT_ALLOWED, "METHOD_NOT_ALLOWED", null, null);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiError> notFound(NoResourceFoundException ex) {
        return respond(HttpStatus.NOT_FOUND, "NOT_FOUND", null, null);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ApiError> responseStatus(ResponseStatusException ex) {
        HttpStatus status = HttpStatus.resolve(ex.getStatusCode().value());
        if (status == null || status.is5xxServerError()) {
            return unexpected(ex);
        }
        return respond(status, status.name(), null, null);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> unexpected(Exception ex) {
        // The only place a stack trace is allowed to surface: the log, tied to the correlation id.
        log.error("Unhandled exception [correlationId={}]", MDC.get(Correlation.MDC_KEY), ex);
        return respond(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", null, null);
    }

    private ResponseEntity<ApiError> respond(HttpStatus status, String code, Object[] args, Map<String, Object> details) {
        Locale locale = LocaleContextHolder.getLocale();
        // Codes without a bundle entry must still yield a localized sentence, never the raw code
        // (docs/06 §Language) — REQUEST_FAILED is the generic fallback message.
        String message = messages.getMessage(code, args, null, locale);
        if (message == null) {
            message = messages.getMessage("REQUEST_FAILED", null, code, locale);
        }
        String correlationId = MDC.get(Correlation.MDC_KEY);
        return ResponseEntity.status(status).body(ApiError.of(code, message, details, correlationId));
    }
}
