# ADR index — Architecture Decision Records

Every deviation from and decision about the canonical docs (`00`–`13`) is recorded here as
`NNNN-<slug>.md` (four-digit ascending number; copy [`0000-template.md`](0000-template.md)) —
see the deviations policy in `12-build-plan.md`. Update the affected doc **in the same PR**,
add the new ADR to this index, and the `sync-wiki` Action mirrors everything to the wiki on merge.

| # | ADR | Status | Date |
|---|---|---|---|
| 0001 | [Implementation lives in the Tishreen-Market repository](0001-implement-in-tishreen-market-repo.md) | accepted | 2026-08-22 |
| 0002 | [GitHub issue branches off `main` instead of phase/feat hierarchy](0002-github-issue-branches.md) | accepted | 2026-08-22 |
| 0003 | [Generic error codes for framework-level failures](0003-generic-error-codes.md) | accepted | 2026-08-22 |
| 0004 | [Add a native mobile app (`apps/mobile`, Expo) alongside the web PWA](0004-add-native-mobile-app-expo.md) | accepted | 2026-08-22 |
| 0005 | [ArchUnit layer dependency matrix and the domain-enum exception](0005-archunit-layer-matrix-domain-enums.md) | accepted | 2026-08-22 |
| 0006 | [`tishreen.ps1` control script and one database per operating mode](0006-tishreen-ps1-three-operating-modes.md) | accepted | 2026-08-22 |
| 0007 | [CI hardening and scope (SonarCloud, SHA pinning, web-only)](0007-ci-hardening-and-scope.md) | accepted | 2026-08-22 |
| 0008 | [Wiki mirror as the authoritative reference (`sync-wiki`)](0008-wiki-sync-authoritative-reference.md) | accepted | 2026-08-22 |
| 0009 | [Plain JDBC in Phase 1; Spring Data JPA and MapStruct from Phase 2](0009-jdbc-phase1-jpa-phase2.md) | accepted | 2026-08-22 |
| 0010 | [Cookie-less refresh-token variant for native clients (`X-Client: mobile`)](0010-native-auth-refresh-token-variant.md) | accepted | 2026-08-23 |
