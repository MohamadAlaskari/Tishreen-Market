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
 * P1-T6 smoke test: Flyway migrates a fresh PostgreSQL 15 under the dev profile — 34 tables
 * (docs/03), the core seed counts of docs/04 Part A, and the V900 dev sample data of Part B.
 */
@SpringBootTest
@ActiveProfiles("dev")
@Testcontainers
class FlywayDevMigrationSmokeTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:15");

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void schemaHasExactly34Tables() {
        Integer tables = jdbc.queryForObject("""
                SELECT count(*) FROM information_schema.tables
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
                  AND table_name <> 'flyway_schema_history'
                """, Integer.class);

        assertThat(tables).isEqualTo(34);
    }

    @Test
    void coreSeedCountsMatchDocs04PartA() {
        assertThat(count("roles")).isEqualTo(5);
        assertThat(count("permissions")).isEqualTo(35);
        assertThat(count("role_permissions")).isEqualTo(59);
        assertThat(count("settings")).isEqualTo(42);
        assertThat(count("theme_settings")).isEqualTo(10);
        assertThat(count("faq_entries")).isEqualTo(4);
    }

    @Test
    void devProfileAppliesV900SampleData() {
        Integer v900 = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version = '900'", Integer.class);

        assertThat(v900).isEqualTo(1);
        assertThat(count("users")).isEqualTo(6);
        assertThat(count("products")).isEqualTo(7);
    }

    @Test
    void stockLedgerMatchesTheCachedStock() {
        // Truth is SUM(stock_movements); products.stock_cached is only a cache — the dev seed
        // must keep both in sync so ledger arithmetic starts out correct.
        Integer mismatches = jdbc.queryForObject("""
                SELECT count(*) FROM products p
                LEFT JOIN v_stock_balance b ON b.product_id = p.id
                WHERE COALESCE(b.balance, 0) <> p.stock_cached
                """, Integer.class);

        assertThat(mismatches).isZero();
    }

    private Integer count(String table) {
        return jdbc.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }
}
