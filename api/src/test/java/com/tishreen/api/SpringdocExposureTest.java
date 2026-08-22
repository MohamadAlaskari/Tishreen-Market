package com.tishreen.api;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

/** springdoc serves the OpenAPI document at /api/v1/docs, dev profile only (docs/06, docs/09). */
class SpringdocExposureTest {

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    @ActiveProfiles("dev")
    class DevProfile {

        @Autowired
        private TestRestTemplate rest;

        @Test
        void servesOpenApiAtTheDocumentedRoute() {
            ResponseEntity<String> response = rest.getForEntity("/api/v1/docs", String.class);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody()).contains("\"openapi\"");
        }
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    class DefaultProfile {

        @Autowired
        private TestRestTemplate rest;

        @Test
        void openApiIsNotExposedOutsideDev() {
            ResponseEntity<String> response = rest.getForEntity("/api/v1/docs", String.class);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        }
    }
}
