# ADR-0009 — Plain JDBC in Phase 1; Spring Data JPA and MapStruct from Phase 2

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session c267f784)

## Context
`docs/00-overview.md` §4 locks the backend stack to Spring Data JPA (+ MapStruct optional). The
Phase-1 skeleton (`12` P1-T5, #3) shipped on plain `spring-boot-starter-jdbc` instead: Phase 1 has no
domain entities to map — Flyway owns the schema (`V1`/`V2`/`V900`) and the only database consumers are
the health check and the 34-table Testcontainers smoke test, so full JPA would have been empty
scaffolding ahead of need. The deviation went unmarked until #17 added the phasing note to `00 §4`;
this ADR records it as a decision with a target phase (2026-08-22 docs audit, #18).

## Decision
Phase 1 runs on `spring-boot-starter-jdbc` only. Spring Data JPA enters with the first real domain
entities in Phase 2 (`12` P2-T1: `User`, profiles, `Role`, `Permission`); MapStruct stays optional
from then on, as documented. The locked stack of `00 §4` is unchanged as the target — this is a
sequencing decision, not a stack change: once JPA lands, no module introduces its own ad-hoc
persistence style, and Flyway remains the sole owner of DDL (`ddl-auto` stays off).

## Consequences
- Docs updated: the phasing note in `00 §4` (added in #17/PR #27) now references this ADR.
- P2-T1 carries the swap cost: add `spring-boot-starter-data-jpa`, map entities against the existing
  `V1` schema verbatim, repository tests via Testcontainers.
- No data risk: the schema was never JPA-generated, so nothing depends on entity definitions today.
- Rollback: none needed — if Phase 2 slips, the JDBC skeleton keeps working unchanged.
