package com.tishreen.api.shared;

import java.util.Locale;

/**
 * Bilingual text as stored in the DB (*_ar mandatory, *_en optional). Resolution with Arabic
 * fallback happens here so it lives in the service layer, never in SQL or the frontend (rule 3).
 */
public record LocalizedText(String ar, String en) {

    public LocalizedText {
        if (ar == null || ar.isBlank()) {
            throw new IllegalArgumentException("Arabic text is mandatory");
        }
        if (en != null && en.isBlank()) {
            en = null;
        }
    }

    public static LocalizedText of(String ar, String en) {
        return new LocalizedText(ar, en);
    }

    /** Resolves for a language tag ("ar"/"en"); anything but "en" gets Arabic. */
    public String resolve(String lang) {
        if ("en".equalsIgnoreCase(lang) && en != null) {
            return en;
        }
        return ar;
    }

    public String resolve(Locale locale) {
        return resolve(locale == null ? "ar" : locale.getLanguage());
    }
}
