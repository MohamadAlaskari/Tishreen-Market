package com.tishreen.api.shared;

/**
 * Correlation-id constants shared by the filter (platform.logging), the logs and the error body.
 * Lives in shared so no module has to depend on platform for them.
 */
public final class Correlation {

    public static final String HEADER = "X-Correlation-Id";
    public static final String MDC_KEY = "correlationId";

    private Correlation() {
    }
}
