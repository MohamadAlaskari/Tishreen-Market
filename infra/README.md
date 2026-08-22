# infra

Lokale Dev-Umgebung und später Deployment-Artefakte (docs/09 §4, docs/11).

## PostgreSQL 15 — eine Datenbank je Betriebsart

`compose.base.yml` definiert den Postgres-Service; die Overlays `compose.dev.yml` / `compose.nearprod.yml` / `compose.prod.yml` setzen Projektname und Host-Port. Das ergibt drei getrennte Compose-Projekte (`tishreen-dev` 5432 · `tishreen-nearprod` 5532 · `tishreen-prod` 5632) mit eigenen Volumes — sie teilen sich keine Datenbank und können nebeneinander laufen. Bequem über `..\tishreen.ps1`, manuell:

```bash
cp .env.example .env    # optional: Ports/Credentials anpassen (.env bleibt uncommittet)
docker compose -f compose.base.yml -f compose.dev.yml up -d
```

Daten liegen je Betriebsart im benannten Volume `<projekt>_tishreen-pgdata` und überleben Container-Neustarts. Ohne `.env` gelten die Dev-Defaults aus den Compose-Dateien (nur für lokale Entwicklung).

Später hier: `nginx.conf`, `scripts/backup.sh`, `scripts/restore.sh` (Phase 5).
