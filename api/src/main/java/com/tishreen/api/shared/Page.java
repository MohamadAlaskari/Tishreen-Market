package com.tishreen.api.shared;

import java.util.List;
import java.util.function.Function;

/**
 * Pagination envelope for every list endpoint (docs/06 §Pagination):
 * {@code {"content": [...], "page": 0, "size": 20, "totalElements": 135, "totalPages": 7}}.
 */
public record Page<T>(List<T> content, int page, int size, long totalElements, int totalPages) {

    public Page {
        content = List.copyOf(content);
    }

    public static <T> Page<T> of(List<T> content, int page, int size, long totalElements) {
        int totalPages = size <= 0 ? 0 : (int) Math.ceil((double) totalElements / size);
        return new Page<>(content, page, size, totalElements, totalPages);
    }

    public <R> Page<R> map(Function<? super T, ? extends R> mapper) {
        return new Page<>(content.stream().<R>map(mapper).toList(), page, size, totalElements, totalPages);
    }
}
