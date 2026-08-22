---
name: new-migration
description: Create the next Flyway migration for Tishreen from a described schema change — correct version number, types, constraints, indexes, append-only rules — and update tishreen-handoff/tishreen-handoff/docs/02.
argument-hint: <what changes> e.g. "add index on orders(driver_id)"
disable-model-invocation: true
---
Write the next Flyway migration for: **$ARGUMENTS**

Open questions first: if the change leaves a product, scope or architecture question open (ambiguous requirement, docs silent or contradictory, several sensible options), ask Mohamad — short options + a recommendation — and implement only after the answer.

1. List `api/src/main/resources/db/migration/` and compute the next version `V<n+1>`; derive a snake_case description. If `V1__init_schema.sql` does not exist yet, create it from `tishreen-handoff/tishreen-handoff/docs/03-schema.sql` **verbatim** (validated DDL) and `V2__seed_core_data.sql` from `tishreen-handoff/tishreen-handoff/docs/04-seed.sql` Part A; dev data goes to `db/dev/V900__dev_sample_data.sql` (Part B).
2. Never modify a committed migration (the backend hook blocks it). Additive only; destructive changes need an ADR and a data-migration plan.
3. Apply the `tishreen-schema` conventions: `NUMERIC(14,2)`/`(12,3)`, `TIMESTAMPTZ`, `VARCHAR + CHECK`, `ON DELETE RESTRICT`, `is_active`, indexes for every new filter/sort, partial unique indexes where one-per-parent is required.
4. Update `tishreen-handoff/tishreen-handoff/docs/02-data-model.md` (table section + §14 indexes) and, if a new enum value/status appears, every doc that lists vocabularies (`05`, `06`, `tishreen-handoff/tishreen-handoff/CLAUDE.md`).
5. Run `api/mvnw -f api -q test -Dtest=SchemaMigrationIT` and paste the result; then show the DDL.
