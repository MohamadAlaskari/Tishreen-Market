package com.tishreen.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * P1-T6 acceptance: the prod profile migrates schema + core seed but must never apply the
 * V900 dev sample data (docs/04 Part B is classpath:db/dev, dev profile only).
 */
@SpringBootTest
@ActiveProfiles("prod")
@Testcontainers
class FlywayProdMigrationSmokeTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:15");

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void coreSchemaAndSeedAreApplied() {
        Integer roles = jdbc.queryForObject("SELECT count(*) FROM roles", Integer.class);

        assertThat(roles).isEqualTo(5);
    }

    @Test
    void v900DevSampleDataIsNotApplied() {
        Integer v900 = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version = '900'", Integer.class);
        Integer users = jdbc.queryForObject("SELECT count(*) FROM users", Integer.class);

        assertThat(v900).isZero();
        assertThat(users).isZero();
    }
}
