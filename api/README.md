# api

Spring Boot 3.3 / Java 21 / Maven — Modularer Monolith (docs/09). Module:
`identity · catalog · ordering · delivery · loyalty · support · inventory · cms · platform · shared`.

## Starten (dev)

```bash
docker compose -f ../infra/docker-compose.yml up -d postgres   # DB (ab P1-T6 benötigt)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

- Health: `GET http://localhost:8080/actuator/health`
- OpenAPI (nur dev): `http://localhost:8080/api/v1/docs` (docs/06) · Swagger-UI: `http://localhost:8080/swagger-ui/index.html`
- Jede Response trägt `X-Correlation-Id`; Logs als JSON unter `logs/` (`LOGS_DIR` überschreibt).

## Tests

```bash
./mvnw verify
```
