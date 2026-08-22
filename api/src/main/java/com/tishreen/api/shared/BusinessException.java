package com.tishreen.api.shared;

import org.springframework.http.HttpStatus;

import java.util.Map;

/**
 * Business-rule violation carrying a stable error code (docs/06 §Errors) and the HTTP status.
 * The code doubles as the message key in messages_ar/messages_en; args fill its placeholders.
 */
public class BusinessException extends RuntimeException {

    private final String code;
    private final HttpStatus status;
    private final transient Object[] args;
    private final transient Map<String, Object> details;

    public BusinessException(String code, HttpStatus status, Object... args) {
        this(code, status, null, args);
    }

    public BusinessException(String code, HttpStatus status, Map<String, Object> details, Object... args) {
        super(code);
        this.code = code;
        this.status = status;
        this.details = details;
        this.args = args;
    }

    public String code() {
        return code;
    }

    public HttpStatus status() {
        return status;
    }

    public Object[] args() {
        return args;
    }

    public Map<String, Object> details() {
        return details;
    }
}
