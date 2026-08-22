package com.tishreen.api.arch;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.dependencies.SlicesRuleDefinition;

import java.util.stream.Stream;

import static com.tishreen.api.arch.TishreenArchitecture.DOMAIN_MODULES;
import static com.tishreen.api.arch.TishreenArchitecture.PLATFORM;
import static com.tishreen.api.arch.TishreenArchitecture.PROVIDER_SDK_PACKAGES;
import static com.tishreen.api.arch.TishreenArchitecture.ROOT;
import static com.tishreen.api.arch.TishreenArchitecture.SHARED;
import static com.tishreen.api.arch.TishreenArchitecture.composite;
import static com.tishreen.api.arch.TishreenArchitecture.module;
import static com.tishreen.api.arch.TishreenArchitecture.providerImplementations;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * Module boundaries of the modular monolith (docs/09 §2, P1-T7): a module exposes its
 * api/dto/events packages and public service interfaces; domain and infrastructure are
 * module-private. Cross-module needs go through ports; providers live behind interfaces
 * in platform.
 */
@AnalyzeClasses(packages = ROOT, importOptions = ImportOption.DoNotIncludeTests.class)
class ModuleBoundaryRulesTest {

    @ArchTest
    static final ArchRule modules_keep_domain_and_infrastructure_private = composite(
            DOMAIN_MODULES.stream().map(m -> noClasses()
                    .that().resideOutsideOfPackage(module(m) + "..")
                    .should().dependOnClassesThat()
                    .resideInAnyPackage(module(m) + ".domain..", module(m) + ".infrastructure..")
                    .allowEmptyShould(true)))
            .as("no module reaches into another module's domain or infrastructure (docs/09 §2)");

    @ArchTest
    static final ArchRule only_platform_uses_provider_sdks = noClasses()
            .that().resideOutsideOfPackage(PLATFORM)
            .should().dependOnClassesThat().resideInAnyPackage(PROVIDER_SDK_PACKAGES)
            .allowEmptyShould(true)
            .as("only platform imports provider SDKs (docs/09 §2)");

    @ArchTest
    static final ArchRule provider_implementations_reside_in_platform = classes()
            .that(providerImplementations())
            .should().resideInAPackage(PLATFORM)
            .allowEmptyShould(true)
            .as("provider implementations reside in platform (docs/09 §2)");

    @ArchTest
    static final ArchRule only_platform_depends_on_provider_implementations = noClasses()
            .that().resideOutsideOfPackage(PLATFORM)
            .should().dependOnClassesThat(providerImplementations())
            .allowEmptyShould(true)
            .as("modules use providers only through the platform interfaces, never a concrete implementation");

    @ArchTest
    static final ArchRule shared_depends_on_no_module = noClasses()
            .that().resideInAPackage(SHARED)
            .should().dependOnClassesThat().resideInAnyPackage(
                    Stream.concat(DOMAIN_MODULES.stream().map(m -> module(m) + ".."), Stream.of(PLATFORM))
                            .toArray(String[]::new))
            .allowEmptyShould(true)
            .as("shared is the base layer and depends on no module (docs/09 §1)");

    @ArchTest
    static final ArchRule modules_are_free_of_cycles = SlicesRuleDefinition.slices()
            .matching(ROOT + ".(*)..")
            .should().beFreeOfCycles();
}
