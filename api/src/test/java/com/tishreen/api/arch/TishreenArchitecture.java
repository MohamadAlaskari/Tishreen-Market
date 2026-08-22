package com.tishreen.api.arch;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.CompositeArchRule;

import java.util.List;
import java.util.stream.Stream;

import static com.tngtech.archunit.base.DescribedPredicate.describe;
import static com.tngtech.archunit.base.DescribedPredicate.not;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.INTERFACES;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.assignableTo;

/**
 * Shared vocabulary of the architecture tests (docs/09 §2, docs/13 §2).
 *
 * <p>Most module packages are still empty at P1-T7, therefore every rule that quantifies over
 * module content uses {@code allowEmptyShould(true)} — the rules are dormant until the first
 * class arrives and bind from that moment on.
 */
final class TishreenArchitecture {

    static final String ROOT = "com.tishreen.api";

    /** Domain modules sharing the internal layout api/application/domain/dto/infrastructure/events. */
    static final List<String> DOMAIN_MODULES =
            List.of("identity", "catalog", "ordering", "delivery", "loyalty", "support", "inventory", "cms");

    static final String PLATFORM = ROOT + ".platform..";
    static final String SHARED = ROOT + ".shared..";

    /**
     * Provider abstractions (docs/09 §2). Referenced by fully qualified name because the
     * interfaces only arrive in later phases; {@code assignableTo(String)} matches by name,
     * so the rules take effect with the first implementation.
     */
    static final List<String> PROVIDER_INTERFACES = List.of(
            ROOT + ".platform.notification.NotificationChannel",
            ROOT + ".platform.storage.ImageStorage",
            ROOT + ".platform.payment.PaymentProvider",
            ROOT + ".platform.chatbot.ChatbotProvider");

    /** SDK root packages of the providers named in docs/09 (telegram, sms, minio/s3, payment, llm). */
    static final String[] PROVIDER_SDK_PACKAGES = {
            "org.telegram..", "com.twilio..", "com.vonage..",
            "io.minio..", "software.amazon.awssdk..", "com.amazonaws..",
            "com.stripe..", "com.openai..", "com.anthropic.."};

    static final DescribedPredicate<JavaClass> ENUMS = describe("enums", JavaClass::isEnum);

    private TishreenArchitecture() {
    }

    static String module(String name) {
        return ROOT + "." + name;
    }

    static String[] domainPackages() {
        return DOMAIN_MODULES.stream().map(m -> module(m) + ".domain..").toArray(String[]::new);
    }

    /** Concrete classes implementing one of the provider abstractions — the interfaces themselves stay importable. */
    static DescribedPredicate<JavaClass> providerImplementations() {
        DescribedPredicate<JavaClass> implementsAny = PROVIDER_INTERFACES.stream()
                .map(name -> assignableTo(name))
                .reduce(DescribedPredicate.<JavaClass>alwaysFalse(), (a, b) -> a.or(b));
        return implementsAny.and(not(INTERFACES))
                .as("provider implementations (NotificationChannel / ImageStorage / PaymentProvider / ChatbotProvider)");
    }

    static ArchRule composite(Stream<ArchRule> rules) {
        List<ArchRule> all = rules.toList();
        CompositeArchRule result = CompositeArchRule.of(all.get(0));
        for (ArchRule rule : all.subList(1, all.size())) {
            result = result.and(rule);
        }
        return result;
    }
}
