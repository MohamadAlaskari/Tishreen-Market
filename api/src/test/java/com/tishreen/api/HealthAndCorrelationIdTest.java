package com.tishreen.api;

import com.tishreen.api.shared.Correlation;
import com.tishreen.api.testsupport.TestProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/** Covers the P1-T5 acceptance criteria: health UP and X-Correlation-Id on every response. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = TestProperties.NO_DATABASE)
class HealthAndCorrelationIdTest {

    @Autowired
    private TestRestTemplate rest;

    @Test
    void healthIsUp() {
        ResponseEntity<String> response = rest.getForEntity("/actuator/health", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("\"status\":\"UP\"");
    }

    @Test
    void everyResponseCarriesAGeneratedCorrelationId() {
        ResponseEntity<String> response = rest.getForEntity("/actuator/health", String.class);

        String id = response.getHeaders().getFirst(Correlation.HEADER);
        assertThat(id).isNotBlank();
    }

    @Test
    void incomingCorrelationIdIsEchoed() {
        HttpHeaders headers = new HttpHeaders();
        headers.set(Correlation.HEADER, "test-correlation-42");

        ResponseEntity<String> response = rest.exchange(
                "/actuator/health", HttpMethod.GET, new HttpEntity<>(headers), String.class);

        assertThat(response.getHeaders().getFirst(Correlation.HEADER)).isEqualTo("test-correlation-42");
    }

    @Test
    void invalidIncomingCorrelationIdIsReplaced() {
        HttpHeaders headers = new HttpHeaders();
        headers.set(Correlation.HEADER, "evil id with spaces and $pecial=chars");

        ResponseEntity<String> response = rest.exchange(
                "/actuator/health", HttpMethod.GET, new HttpEntity<>(headers), String.class);

        String id = response.getHeaders().getFirst(Correlation.HEADER);
        assertThat(id).isNotBlank().matches("[A-Za-z0-9-]+");
    }
}
