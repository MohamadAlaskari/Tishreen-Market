package com.tishreen.api.shared;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/** Verifies the single ApiError shape from docs/06 §Errors via the test-only error endpoints. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GlobalExceptionHandlerTest {

    @Autowired
    private TestRestTemplate rest;

    @Test
    void validationErrorsReturn400WithFieldCodes() {
        ResponseEntity<String> response = postJson("/__test/validated", "{\"name\":\"\"}", null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody())
                .contains("\"code\":\"VALIDATION_FAILED\"")
                .contains("\"fields\"")
                .contains("\"field\":\"name\"")
                .contains("\"correlationId\"");
    }

    @Test
    void malformedJsonReturns400() {
        ResponseEntity<String> response = postJson("/__test/validated", "{not-json", null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("\"code\":\"VALIDATION_FAILED\"");
    }

    @Test
    void businessExceptionCarriesItsStatusAndLocalizedMessage() {
        ResponseEntity<String> response = rest.getForEntity("/__test/business", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.LOCKED);
        // Arabic is the default language when no Accept-Language is sent (docs/06)
        assertThat(response.getBody())
                .contains("\"code\":\"STORE_CLOSED\"")
                .contains("المتجر مغلق");
    }

    @Test
    void acceptLanguageEnSwitchesTheMessage() {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.ACCEPT_LANGUAGE, "en");

        ResponseEntity<String> response = rest.exchange(
                "/__test/business", HttpMethod.GET, new HttpEntity<>(headers), String.class);

        assertThat(response.getBody()).contains("The store is currently closed.");
    }

    @Test
    void unexpectedErrorsReturn500WithoutLeakingDetails() {
        ResponseEntity<String> response = rest.getForEntity("/__test/boom", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody())
                .contains("\"code\":\"INTERNAL_ERROR\"")
                .contains("\"correlationId\"")
                .doesNotContain("sensitive-internal-detail")
                .doesNotContain("IllegalStateException");
    }

    @Test
    void unknownPathReturns404ApiError() {
        ResponseEntity<String> response = rest.getForEntity("/does-not-exist", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).contains("\"code\":\"NOT_FOUND\"");
    }

    @Test
    void wrongMethodReturns405ApiError() {
        ResponseEntity<String> response = rest.getForEntity("/__test/validated", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.METHOD_NOT_ALLOWED);
        assertThat(response.getBody()).contains("\"code\":\"METHOD_NOT_ALLOWED\"");
    }

    private ResponseEntity<String> postJson(String path, String body, String acceptLanguage) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (acceptLanguage != null) {
            headers.set(HttpHeaders.ACCEPT_LANGUAGE, acceptLanguage);
        }
        return rest.exchange(path, HttpMethod.POST, new HttpEntity<>(body, headers), String.class);
    }
}
