package com.tishreen.api.shared;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class PageTest {

    @Test
    void computesTotalPages() {
        // docs/06 example: 135 elements at size 20 -> 7 pages
        Page<String> page = Page.of(List.of("a"), 0, 20, 135);
        assertThat(page.totalPages()).isEqualTo(7);
        assertThat(page.totalElements()).isEqualTo(135);
    }

    @Test
    void emptyResult() {
        Page<String> page = Page.of(List.of(), 0, 20, 0);
        assertThat(page.totalPages()).isZero();
        assertThat(page.content()).isEmpty();
    }

    @Test
    void mapsContentKeepingMetadata() {
        Page<Integer> page = Page.of(List.of(1, 2), 1, 2, 4);
        Page<String> mapped = page.map(String::valueOf);
        assertThat(mapped.content()).containsExactly("1", "2");
        assertThat(mapped.page()).isEqualTo(1);
        assertThat(mapped.size()).isEqualTo(2);
        assertThat(mapped.totalPages()).isEqualTo(2);
    }
}
