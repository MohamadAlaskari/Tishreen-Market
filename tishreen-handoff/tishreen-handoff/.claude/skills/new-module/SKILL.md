---
name: new-module
description: Scaffold a new backend module (or the next one in the build plan) inside the Tishreen modular monolith with the standard package layout, ArchUnit rule, ports, and test skeletons.
argument-hint: <module-name> e.g. ordering
disable-model-invocation: true
---
Scaffold the backend module **$ARGUMENTS** following `docs/09-architecture.md` §2 and the `spring-modular-monolith` skill.

1. Confirm the module is one of `identity catalog ordering delivery loyalty support inventory cms platform shared`; otherwise stop and ask (new modules need an ADR).
2. Create `api/src/main/java/com/tishreen/api/$ARGUMENTS/{api,application,domain/model,infrastructure,dto,events,ports}/package-info.java` with a one-line javadoc each.
3. Add the module's tables from the `tishreen-schema` skill as JPA entities in `domain/model` (exact `@Table`/`@Column` names, `@Enumerated(STRING)`, `BigDecimal` precision/scale, `OffsetDateTime`, `@Version` where listed) and Spring Data repositories in `infrastructure`.
4. Create the application service interface + impl for the first use case listed for this module in `docs/12-build-plan.md`, with `@Transactional`, `@Audited` where the action is mandatory, and a `BusinessException` for each error code in `docs/06 §2` that belongs to the module.
5. Add the ArchUnit slice rule for the module in `ArchitectureTest` and a `package-info` `@ApplicationModule` comment listing allowed dependencies.
6. Create test skeletons named per `docs/13 §2` (`@Disabled("P<n>")` for cases not yet implemented).
7. Run `./mvnw -q test -Dtest=ArchitectureTest` and report the file list.
