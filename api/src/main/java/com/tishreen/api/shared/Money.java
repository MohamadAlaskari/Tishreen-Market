package com.tishreen.api.shared;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Objects;

/**
 * Monetary amount in SYP. Always scale 2, HALF_UP; serialized as a plain string
 * ("180000.00") so clients never touch floats (docs/06 §Common DTOs, rule 9).
 */
public final class Money implements Comparable<Money> {

    public static final Money ZERO = new Money(BigDecimal.ZERO);

    private final BigDecimal amount;

    private Money(BigDecimal amount) {
        this.amount = amount.setScale(2, RoundingMode.HALF_UP);
    }

    public static Money of(BigDecimal amount) {
        Objects.requireNonNull(amount, "amount must not be null");
        return new Money(amount);
    }

    @JsonCreator
    public static Money of(String amount) {
        Objects.requireNonNull(amount, "amount must not be null");
        return new Money(new BigDecimal(amount));
    }

    public BigDecimal amount() {
        return amount;
    }

    public Money add(Money other) {
        return new Money(amount.add(other.amount));
    }

    public Money subtract(Money other) {
        return new Money(amount.subtract(other.amount));
    }

    /** Line total = unit price × quantity (quantity uses scale 3, e.g. "1.250" kg). */
    public Money multiply(BigDecimal quantity) {
        Objects.requireNonNull(quantity, "quantity must not be null");
        return new Money(amount.multiply(quantity));
    }

    public boolean isNegative() {
        return amount.signum() < 0;
    }

    public boolean isZero() {
        return amount.signum() == 0;
    }

    @Override
    public int compareTo(Money other) {
        return amount.compareTo(other.amount);
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof Money other && amount.equals(other.amount);
    }

    @Override
    public int hashCode() {
        return amount.hashCode();
    }

    @JsonValue
    @Override
    public String toString() {
        return amount.toPlainString();
    }
}
