package com.tishreen.api.shared;

import org.junit.jupiter.api.Test;

import java.util.Locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class LocalizedTextTest {

    @Test
    void arabicIsMandatory() {
        assertThatThrownBy(() -> LocalizedText.of(null, "Apples")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> LocalizedText.of("  ", "Apples")).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void blankEnglishBecomesNull() {
        assertThat(LocalizedText.of("تفاح", "  ").en()).isNull();
    }

    @Test
    void resolvesEnglishWhenPresent() {
        LocalizedText text = LocalizedText.of("تفاح", "Apples");
        assertThat(text.resolve("en")).isEqualTo("Apples");
        assertThat(text.resolve(Locale.ENGLISH)).isEqualTo("Apples");
    }

    @Test
    void fallsBackToArabic() {
        LocalizedText noEnglish = LocalizedText.of("تفاح", null);
        assertThat(noEnglish.resolve("en")).isEqualTo("تفاح");
        assertThat(noEnglish.resolve("ar")).isEqualTo("تفاح");
        assertThat(noEnglish.resolve((Locale) null)).isEqualTo("تفاح");
        // unknown languages get Arabic, the default (docs/10)
        assertThat(LocalizedText.of("تفاح", "Apples").resolve("fr")).isEqualTo("تفاح");
    }
}
