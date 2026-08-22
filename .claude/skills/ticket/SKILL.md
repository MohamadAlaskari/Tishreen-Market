---
name: ticket
description: MANDATORY workflow for every GitHub issue (ticket) operation in this repo — create, edit, close, or link tickets, always with symmetric dependency tracking (Blocked by / Blocks mirrored on both issues, blocked label maintained). Also defines the handover after implementing a ticket - commit message + git command with file list, PR title and PR description. Use whenever a ticket/issue is created, changed, closed, or an implementation is finished.
---

# Ticket-Workflow (GitHub Issues)

Repo: das `origin`-Remote des aktuellen Verzeichnisses (derzeit `MohamadAlaskari/Tishreen-Market`).
Voraussetzung: `gh` CLI eingeloggt (`gh auth status`). Falls nicht: stoppen und den Nutzer bitten, `gh auth login` auszuführen.

**Eiserne Regeln (gelten für jeden Abschnitt):**
1. Mehrzeilige Bodies IMMER über eine Temp-Datei (`--body-file`), nie inline in `-b`.
2. Abhängigkeiten sind IMMER symmetrisch: Wer in Ticket A `Blocked by: #B` einträgt, trägt im selben Arbeitsgang in #B `Blocks: #A` ein — und umgekehrt. Auch beim ENTFERNEN einer Abhängigkeit beide Seiten anpassen. Nie nur eine Seite editieren.
3. Label `blocked` ist genau dann gesetzt, wenn mindestens ein Ticket aus `Blocked by:` noch OPEN ist. Nach jeder Abhängigkeits- oder Statusänderung auf allen berührten Tickets neu prüfen.
4. Die Marker `Blocked by:` und `Blocks:` sind maschinenlesbar — exakt so schreiben, nie übersetzen. Titel und Commits auf Englisch (Projektregel); Body-Prosa darf Deutsch sein.
5. Jede inhaltliche Änderung an einem Ticket bekommt einen kurzen Kommentar auf dem Ticket (was wurde geändert, warum) — so erfahren Beobachter und abhängige Tickets davon.

## 1. Ticket anlegen

1. **Duplikate prüfen:** `gh issue list --state all --search "<Stichworte>" --limit 10`. Existiert ein passendes Ticket → stattdessen Abschnitt 2 (ändern) und das dem Nutzer sagen.
2. **Label sicherstellen** (idempotent):
   `gh label create blocked --color D93F0B --description "Wartet auf ein anderes Ticket" 2>/dev/null || true`
3. **Body nach diesem Template** (Struktur exakt einhalten, `Dependencies`-Block auch wenn leer):

   ```markdown
   ## Context
   Warum / Ziel. Verweise auf die Spezifikation, z. B. tishreen-handoff/tishreen-handoff/docs/05 §1, F-21, Figma-Node.

   ## Scope / Tasks
   - [ ] ...

   ## Acceptance criteria
   - ...

   ## Dependencies
   - Blocked by: #12, #15
   - Blocks: #20

   ## References
   tishreen-handoff/tishreen-handoff/docs/<datei> · verwandt: #N
   ```

   Keine Abhängigkeit → `- Blocked by: none` / `- Blocks: none`.
4. **Anlegen:**
   ```bash
   gh issue create --title "feat(ordering): finalize order pricing" --body-file "$TEMP/ticket-body.md"
   # + --label blocked  wenn "Blocked by" mindestens ein offenes Ticket enthält
   ```
5. **Gegenseiten spiegeln (Pflicht, sofort):**
   - Für jedes `#B` in `Blocked by:` → Body von #B holen (`gh issue view B --json body`), `#NEU` in dessen `Blocks:`-Zeile ergänzen (Dependencies-Sektion anlegen, falls sie fehlt), `gh issue edit B --body-file …`, Kommentar: `Blocks #NEU (neu angelegt).`
   - Für jedes `#C` in `Blocks:` → in #C `Blocked by: … #NEU` ergänzen, Label `blocked` auf #C setzen, Kommentar: `Blocked by #NEU (neu angelegt).`
6. Dem Nutzer Ticket-Nummer + URL nennen und die gespiegelten Tickets auflisten.

## 2. Ticket ändern

1. Ist-Zustand holen: `gh issue view N --json title,body,labels,state,url`.
2. Änderung im Body/Titel anwenden: `gh issue edit N --title … --body-file …`.
3. **Wenn sich die `Dependencies`-Sektion geändert hat** (hinzugefügt ODER entfernt):
   - Diff der alten vs. neuen `Blocked by:`/`Blocks:`-Listen bilden.
   - Für jede hinzugefügte Beziehung: Gegenseite ergänzen (wie 1.5).
   - Für jede entfernte Beziehung: den Verweis auf `#N` auch aus der Gegenseite löschen + Kommentar dort.
   - Danach auf ALLEN berührten Tickets das `blocked`-Label neu berechnen (Regel 3): Status jedes Blockers mit `gh issue view B --json state` prüfen; kein offener Blocker mehr → `gh issue edit X --remove-label blocked`.
4. Kommentar auf #N: was geändert wurde und warum (Regel 5).

## 3. Ticket schließen / Blocker erledigt

Beim Schließen von #N (erledigt oder verworfen):
1. Die eigene `Blocks:`-Liste von #N ist die maßgebliche Liste der Abhängigen (dank Regel 2 vollständig).
2. Für jedes abhängige Ticket #X:
   - In dessen `Blocked by:`-Zeile `#N` als erledigt markieren: `~~#N~~ ✔` (nicht löschen — Historie).
   - Sind alle Blocker von #X geschlossen → `gh issue edit X --remove-label blocked` + Kommentar: `Blocker #N erledigt — Ticket ist entsperrt.` Sonst Kommentar: `Blocker #N erledigt — wartet noch auf: #…`.
3. Schließen: `gh issue close N --comment "<kurzes Ergebnis, Verweis auf Commit/PR>"`.
   (Wird das Ticket per PR-Merge mit `Closes #N` automatisch geschlossen, danach trotzdem Schritt 1–2 ausführen.)

## 4. Übergabe nach Implementierung (Pflicht nach jedem umgesetzten Ticket)

Nach dem Implementieren eines Tickets IMMER diese drei Artefakte liefern, in dieser Reihenfolge:

**a) Commit — Text und Kommando mit Dateiliste** (nie blind `git add -A`; genau die Dateien des Tickets):
```bash
git add api/src/main/java/com/tishreen/api/ordering/application/PricingService.java \
        api/src/test/java/com/tishreen/api/ordering/PricingServiceTest.java
git commit -m "feat(ordering): finalize order pricing (#42)

Recompute line totals from actual weights; cap FIXED offers at actual goods."
```
Format: `type(scope): summary (#ticket)` — conventional commit, Scope = Modul, Ticket-Nummer im Titel. Nie einen `Co-Authored-By`-Trailer oder eine andere KI-Attribution anhängen (Projektregel: alles läuft unter Mohamads Namen).

**b) PR-Titel:** identisch zum Commit-Summary, z. B. `feat(ordering): finalize order pricing (#42)`.

**c) PR-Beschreibung** nach diesem Template:
```markdown
## Summary
Was wurde umgesetzt und warum (1–3 Sätze, Bezug zur Spezifikation).

## Changes
- …

## Tests
- Welche Tests neu/angepasst, wie verifiziert.

## Tickets
Closes #42
Entsperrt danach: #43, #44   <!-- aus der Blocks:-Liste des Tickets -->
```

Wird der PR direkt angelegt: `gh pr create --title "…" --body-file "$TEMP/pr-body.md"`. Nach dem Merge Abschnitt 3 für die abhängigen Tickets ausführen.
