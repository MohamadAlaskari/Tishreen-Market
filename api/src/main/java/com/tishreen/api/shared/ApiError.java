package com.tishreen.api.shared;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.Map;

/**
 * The one and only error body shape (docs/06 §Errors):
 * {@code {"code": "...", "message": "<localized>", "details": {...}, "correlationId": "..."}}.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiError(String code, String message, Map<String, Object> details, String correlationId) {

    public static ApiError of(String code, String message, String correlationId) {
        return new ApiError(code, message, null, correlationId);
    }

    public static ApiError of(String code, String message, Map<String, Object> details, String correlationId) {
        return new ApiError(code, message, details, correlationId);
    }
}
