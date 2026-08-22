package com.tishreen.api.shared;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MoneyTest {

    @Test
    void normalizesToScaleTwoHalfUp() {
        assertThat(Money.of("180000.005").toString()).isEqualTo("180000.01");
        assertThat(Money.of("180000.004").toString()).isEqualTo("180000.00");
        assertThat(Money.of("180000").toString()).isEqualTo("180000.00");
    }

    @Test
    void serializesAsPlainString() {
        assertThat(Money.of(new BigDecimal("1E+3")).toString()).isEqualTo("1000.00");
    }

    @Test
    void addsAndSubtracts() {
        Money total = Money.of("100.50").add(Money.of("0.50"));
        assertThat(total).isEqualTo(Money.of("101.00"));
        assertThat(total.subtract(Money.of("1.00"))).isEqualTo(Money.of("100.00"));
    }

    @Test
    void multipliesByQuantityScaleThree() {
        // 3200.00 SYP/kg × 1.250 kg = 4000.00
        assertThat(Money.of("3200.00").multiply(new BigDecimal("1.250"))).isEqualTo(Money.of("4000.00"));
        // rounding case: 10.00 × 0.333 = 3.33
        assertThat(Money.of("10.00").multiply(new BigDecimal("0.333"))).isEqualTo(Money.of("3.33"));
    }

    @Test
    void signChecks() {
        assertThat(Money.ZERO.isZero()).isTrue();
        assertThat(Money.of("-1.00").isNegative()).isTrue();
        assertThat(Money.of("1.00").isNegative()).isFalse();
    }

    @Test
    void equalityIgnoresSourceScale() {
        assertThat(Money.of("5")).isEqualTo(Money.of("5.00"));
    }

    @Test
    void rejectsNull() {
        assertThatThrownBy(() -> Money.of((BigDecimal) null)).isInstanceOf(NullPointerException.class);
        assertThatThrownBy(() -> Money.of((String) null)).isInstanceOf(NullPointerException.class);
    }
}
