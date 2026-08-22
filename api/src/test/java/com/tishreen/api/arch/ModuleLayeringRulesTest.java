package com.tishreen.api.arch;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import java.util.Set;
import java.util.stream.Stream;

import static com.tishreen.api.arch.TishreenArchitecture.DOMAIN_MODULES;
import static com.tishreen.api.arch.TishreenArchitecture.ENUMS;
import static com.tishreen.api.arch.TishreenArchitecture.ROOT;
import static com.tishreen.api.arch.TishreenArchitecture.composite;
import static com.tishreen.api.arch.TishreenArchitecture.domainPackages;
import static com.tishreen.api.arch.TishreenArchitecture.module;
import static com.tngtech.archunit.base.DescribedPredicate.describe;
import static com.tngtech.archunit.base.DescribedPredicate.not;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.resideInAPackage;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.resideInAnyPackage;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;

/**
 * Internal layering of every domain module (docs/09 §2, docs/13 §2):
 * api → application → { domain, dto, events, infrastructure }; infrastructure → { domain, dto };
 * dto and events are plain data carriers; domain is the innermost layer.
 *
 * <p>Domain enums (e.g. OrderStatus) are the one deliberate exception: web layer, dto and
 * events may reference them — entities and everything else in domain stay off-limits there.
 */
@AnalyzeClasses(packages = ROOT, importOptions = ImportOption.DoNotIncludeTests.class)
class ModuleLayeringRulesTest {

    @ArchTest
    static final ArchRule domain_is_the_innermost_layer = composite(
            DOMAIN_MODULES.stream().map(m -> noClasses()
                    .that().resideInAPackage(module(m) + ".domain..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            module(m) + ".api..", module(m) + ".application..",
                            module(m) + ".dto..", module(m) + ".infrastructure..", module(m) + ".events..")
                    .allowEmptyShould(true)))
            .as("domain depends on no other layer of its module");

    @ArchTest
    static final ArchRule web_layer_uses_services_and_dtos_only = composite(
            DOMAIN_MODULES.stream().map(m -> noClasses()
                    .that().resideInAPackage(module(m) + ".api..")
                    .should().dependOnClassesThat(
                            resideInAPackage(module(m) + ".infrastructure..")
                                    .or(resideInAPackage(module(m) + ".domain..").and(not(ENUMS))))
                    .allowEmptyShould(true)))
            .as("controllers touch neither repositories nor entities (docs/13 §2) — only services, DTOs and domain enums");

    @ArchTest
    static final ArchRule application_does_not_depend_on_the_web_layer = composite(
            DOMAIN_MODULES.stream().map(m -> noClasses()
                    .that().resideInAPackage(module(m) + ".application..")
                    .should().dependOnClassesThat().resideInAPackage(module(m) + ".api..")
                    .allowEmptyShould(true)))
            .as("application does not depend on the web layer");

    @ArchTest
    static final ArchRule infrastructure_serves_only_the_layers_below = composite(
            DOMAIN_MODULES.stream().map(m -> noClasses()
                    .that().resideInAPackage(module(m) + ".infrastructure..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            module(m) + ".api..", module(m) + ".application..")
                    .allowEmptyShould(true)))
            .as("infrastructure depends only on domain and dto of its module");

    @ArchTest
    static final ArchRule dtos_and_events_carry_data_only = composite(
            DOMAIN_MODULES.stream().flatMap(m ->
                    Stream.of(module(m) + ".dto..", module(m) + ".events..").map(pkg -> noClasses()
                            .that().resideInAPackage(pkg)
                            .should().dependOnClassesThat(
                                    resideInAnyPackage(module(m) + ".api..", module(m) + ".application..",
                                            module(m) + ".infrastructure..")
                                            .or(resideInAPackage(module(m) + ".domain..").and(not(ENUMS))))
                            .allowEmptyShould(true))))
            .as("dto and events are plain data carriers (shared types and domain enums only)");

    @ArchTest
    static final ArchRule domain_avoids_legacy_date_types = noClasses()
            .that().resideInAnyPackage(domainPackages())
            .should().dependOnClassesThat().belongToAnyOf(
                    java.util.Date.class, java.util.Calendar.class, java.sql.Date.class, java.sql.Timestamp.class)
            .allowEmptyShould(true)
            .as("domain uses OffsetDateTime, never java.util.Date (docs/09 §2, docs/13 §2)");

    private static final Set<String> FLOATING_POINT_TYPES =
            Set.of("double", "float", "java.lang.Double", "java.lang.Float");

    @ArchTest
    static final ArchRule domain_money_and_quantities_are_bigdecimal = noFields()
            .that().areDeclaredInClassesThat().resideInAnyPackage(domainPackages())
            .should().haveRawType(describe("double or float", type -> FLOATING_POINT_TYPES.contains(type.getName())))
            .allowEmptyShould(true)
            .as("domain fields never use double/float — BigDecimal only (docs/13 §2)");
}
