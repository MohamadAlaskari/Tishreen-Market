package com.tishreen.api.testsupport;

import com.tishreen.api.shared.BusinessException;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.validation.annotation.Validated;

/** Test-only endpoints that provoke each GlobalExceptionHandler branch. Lives in test sources. */
@RestController
public class TestErrorsController {

    public record SampleRequest(@NotBlank String name) {
    }

    @PostMapping("/__test/validated")
    public String validated(@Validated @RequestBody SampleRequest request) {
        return request.name();
    }

    @GetMapping("/__test/boom")
    public String boom() {
        throw new IllegalStateException("sensitive-internal-detail");
    }

    @GetMapping("/__test/business")
    public String business() {
        throw new BusinessException("STORE_CLOSED", HttpStatus.LOCKED);
    }
}
