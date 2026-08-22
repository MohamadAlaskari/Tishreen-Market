package com.tishreen.api.testsupport;

/** Shared property sets for integration tests. */
public final class TestProperties {

    /**
     * Web-slice tests run without a database: DataSource and Flyway auto-configuration are
     * switched off so they stay fast and Docker-free. Schema and seed coverage lives in the
     * Flyway smoke tests (Testcontainers).
     */
    public static final String NO_DATABASE =
            "spring.autoconfigure.exclude="
            + "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
            + "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration";

    private TestProperties() {
    }
}
