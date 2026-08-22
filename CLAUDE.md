# Tishreen Mall — Workspace-Regeln

- **Tickets nur über die Skill `ticket`** (`.claude/skills/ticket/SKILL.md`): jedes Anlegen, Ändern, Schließen oder Verknüpfen von GitHub-Issues läuft über diesen Workflow — nie über rohe `gh issue`-Befehle daran vorbei. Abhängigkeiten (`Blocked by:` / `Blocks:`) immer auf **beiden** Tickets pflegen; Label `blocked`, solange ein Blocker offen ist.
- **Nach der Implementierung eines Tickets** immer die Übergabe aus Skill-Abschnitt 4 liefern: Commit-Text + `git add`/`git commit`-Kommando mit Dateiliste, PR-Titel und PR-Beschreibung.
- **Kanonische Docs & Regeln** liegen in `tishreen-handoff/tishreen-handoff/` und werden ins GitHub-Wiki gespiegelt (`scripts/sync-wiki.sh`, GitHub Action `sync-wiki`). Änderungen an diesen Quellen → committen + pushen, das Wiki zieht automatisch nach; nie direkt im Wiki editieren.
