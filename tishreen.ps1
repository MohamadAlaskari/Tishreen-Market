#Requires -Version 5.1
<#
tishreen.ps1 - Menu-driven control script for the local dev stack (issue #11).

Drives the three parts of docs/09-architecture.md section 4 from one place:
  - PostgreSQL in Docker  (infra/docker-compose.yml - Docker is used for the DB only)
  - API on the host       (Spring Boot, profile per operating mode)
  - Web on the host       (Vite dev server or built preview, per operating mode)

Three operating modes ("Betriebsarten"), modeled on eportfolio.ps1 but adapted
to the Tishreen architecture: the target deployment is nginx + systemd
(docs/09 section 5), not containers, so the modes differ in HOW the api and
the web app run on the host - the Docker database stays ONE shared instance.

  DEV       Source run: mvnw spring-boot:run (profile dev), Vite dev server.
            Hot reload; for daily development.
  NEARPROD  Delivery check: built jar + built frontend (vite preview), but
            still profile dev (dev seed V900, Swagger on). Checks the
            artifact, not the production configuration.
  PROD      Built jar with profile prod: no Swagger, no dev seed. Needs a
            clean database (DB_URL/DB_USER/DB_PASSWORD) and real settings;
            without them the API stops on purpose (fail fast).

Usage:
  .\tishreen.ps1                 interactive menu (mode DEV preselected)
  .\tishreen.ps1 -Mode nearprod  interactive menu with a preselected mode
  .\tishreen.ps1 -Check          prerequisites check only (non-interactive)

Runs unchanged on Windows PowerShell 5.1 and PowerShell 7. The script text is
deliberately ASCII-only: PS 5.1 reads UTF-8 without BOM as ANSI and would
garble anything else. DB port and credentials come from infra/.env (fallback:
the defaults in infra/docker-compose.yml); secrets are never printed.
#>
[CmdletBinding()]
param(
    # Operating mode preselection; can be changed in the menu with 'b'.
    [ValidateSet('dev', 'nearprod', 'prod')]
    [string]$Mode = 'dev',
    # Only run the prerequisites check and exit (safe to call non-interactively).
    [switch]$Check
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- locations --
$RepoRoot    = $PSScriptRoot
$ComposeFile = Join-Path $RepoRoot 'infra\docker-compose.yml'
$EnvFile     = Join-Path $RepoRoot 'infra\.env'
$ApiDir      = Join-Path $RepoRoot 'api'
$WebDir      = Join-Path $RepoRoot 'apps\web'
$MobileDir   = Join-Path $RepoRoot 'apps\mobile'

# Common prefix for every docker compose call.
$Compose = @('compose', '-f', $ComposeFile, '--env-file', $EnvFile)

# ------------------------------------------------------------------- modes --
# DEV ports are fixed by the project config (application.yml server.port 8080,
# apps/web "dev": "vite dev --port 3000"). NEARPROD and PROD get their own
# ports so they can run next to a DEV session; the API port is passed via
# --server.port, the web preview via --port.
$Modes = [ordered]@{
    'dev' = @{
        Label   = 'DEV / Quellcode-Betrieb'
        Profil  = 'dev'
        ApiPort = 8080
        WebPort = 3000
        Hinweis = 'mvnw spring-boot:run und Vite-Dev-Server mit Hot Reload. Zum Entwickeln.'
    }
    'nearprod' = @{
        Label   = 'NEARPROD / Auslieferungsstand'
        Profil  = 'dev'
        ApiPort = 8180
        WebPort = 3100
        Hinweis = 'Gebautes Jar und gebautes Frontend (vite preview), aber weiterhin Profil dev: Dev-Seed, Swagger an. Prueft den Auslieferungsstand, nicht die Produktivkonfiguration.'
    }
    'prod' = @{
        Label   = 'PROD / Produktivkonfiguration'
        Profil  = 'prod'
        ApiPort = 8280
        WebPort = 3200
        Hinweis = 'Gebautes Jar mit Profil prod: kein Swagger, kein Dev-Seed. Braucht eine saubere Datenbank (DB_URL/DB_USER/DB_PASSWORD) und echte Werte - ohne sie beendet sich die API absichtlich (Fail-Fast). Ziel-Deployment laut docs/09 Abschnitt 5: nginx + systemd.'
    }
}

$script:Mode = $Mode

function Get-ModeConfig { return $Modes[$script:Mode] }

# ------------------------------------------------------------------ helpers --
function Write-Ok   { param([string]$Text) Write-Host "  [OK]     $Text" -ForegroundColor Green }
function Write-Err  { param([string]$Text) Write-Host "  [FEHLER] $Text" -ForegroundColor Red }
function Write-Warn { param([string]$Text) Write-Host "  [WARN]   $Text" -ForegroundColor Yellow }

function Wait-Enter { [void](Read-Host 'Weiter mit Enter') }

# Runs a native command silently; returns $true when its exit code is 0.
# Stderr is redirected under a temporary ErrorActionPreference=Continue: PS 5.1
# turns redirected stderr lines into ErrorRecords, which would throw under Stop.
function Invoke-Quiet {
    param([string]$File, [string[]]$ArgumentList)
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $File @ArgumentList *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $eap
    }
}

# Quotes arguments for Start-Process -ArgumentList (paths may contain spaces).
function ConvertTo-ArgLine {
    param([string[]]$Items)
    $quoted = foreach ($item in $Items) {
        if ($item -match '[\s"]') { '"' + ($item -replace '"', '\"') + '"' } else { $item }
    }
    return ($quoted -join ' ')
}

# infra/.env -> hashtable (KEY=VALUE lines; comments and blanks ignored).
function Read-DotEnv {
    param([string]$Path)
    $map = @{}
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            $t = "$line".TrimStart([char]0xFEFF).Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $i = $t.IndexOf('=')
            if ($i -lt 1) { continue }
            $map[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
        }
    }
    return $map
}

# DB name/user/port from infra/.env; the fallbacks mirror the defaults in
# infra/docker-compose.yml. POSTGRES_PASSWORD is deliberately never read:
# the script does not need it and must never print it.
function Get-DbConfig {
    $vars = Read-DotEnv -Path $EnvFile
    $cfg = @{ Db = 'tishreen'; User = 'tishreen'; Port = '5432' }
    if ($vars.ContainsKey('POSTGRES_DB'))   { $cfg.Db   = $vars['POSTGRES_DB'] }
    if ($vars.ContainsKey('POSTGRES_USER')) { $cfg.User = $vars['POSTGRES_USER'] }
    if ($vars.ContainsKey('POSTGRES_PORT')) { $cfg.Port = $vars['POSTGRES_PORT'] }
    return $cfg
}

function Test-TcpPort {
    param([int]$Port)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(3000)) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

# HTTP status of $Url. Deliberately curl.exe, not Invoke-WebRequest: the .NET
# web stack runs into timeouts against the Vite dev server and reports false
# alarms. Returns the status code, -1 for "port open" (TCP fallback when
# curl.exe is missing) or $null for unreachable.
function Get-HttpStatus {
    param([string]$Url, [int]$Port)
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        $eap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $code = [string](& $curl.Source --silent --output NUL --write-out '%{http_code}' --max-time 5 $Url 2> $null)
        } catch {
            $code = ''
        } finally {
            $ErrorActionPreference = $eap
        }
        if ($code -match '^[0-9]{3}$' -and $code -ne '000') { return [int]$code }
        return $null
    }
    if (Test-TcpPort -Port $Port) { return -1 }
    return $null
}

# Newest Spring Boot jar in api/target (repackaged fat jar; .original and
# sources jars are skipped). $null when nothing has been built yet.
function Find-ApiJar {
    $targetDir = Join-Path $ApiDir 'target'
    if (-not (Test-Path -LiteralPath $targetDir)) { return $null }
    $jars = @(Get-ChildItem -LiteralPath $targetDir -Filter '*.jar' |
        Where-Object { $_.Name -notlike '*-sources.jar' -and $_.Name -notlike '*-javadoc.jar' } |
        Sort-Object -Property LastWriteTime -Descending)
    if ($jars.Count -eq 0) { return $null }
    return $jars[0]
}

# ------------------------------------------------------------- prerequisites --

# Offers to start Docker Desktop and waits for the daemon (manual start is the
# normal case on this machine). Returns $true once the daemon answers.
function Request-DockerDesktopStart {
    $exe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (-not (Test-Path -LiteralPath $exe)) { return $false }
    Write-Host ''
    Write-Host 'Der Docker-Daemon ist nicht erreichbar, Docker Desktop ist aber installiert.'
    $answer = Read-Host 'Docker Desktop jetzt starten? [j/n]'
    if ($answer -ne 'j') { return $false }
    Start-Process -FilePath $exe
    Write-Host 'Warte auf den Docker-Daemon (bis zu 90 Sekunden) ...'
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 3
        if (Invoke-Quiet 'docker' @('info')) {
            Write-Ok 'Docker-Daemon erreichbar.'
            return $true
        }
    }
    return $false
}

# Collects every missing prerequisite as its own clear message - instead of
# letting compose or maven fail later with raw errors.
function Test-Prerequisites {
    param([switch]$OfferDockerStart)
    $problems = @()

    if (-not (Test-Path -LiteralPath $ComposeFile)) {
        $problems += "Compose-Datei fehlt: $ComposeFile - Repository unvollstaendig?"
    }
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        $problems += 'infra\.env fehlt. Vorlage kopieren:  Copy-Item infra\.env.example infra\.env'
    }

    if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
        $problems += 'docker ist nicht im PATH. Docker Desktop installieren (https://docs.docker.com/desktop/).'
    } else {
        if (-not (Invoke-Quiet 'docker' @('compose', 'version'))) {
            $problems += 'Docker Compose v2 fehlt ("docker compose version" schlaegt fehl). Docker Desktop aktualisieren.'
        }
        $daemonUp = Invoke-Quiet 'docker' @('info')
        if (-not $daemonUp -and $OfferDockerStart) {
            $daemonUp = Request-DockerDesktopStart
        }
        if (-not $daemonUp) {
            $problems += 'Der Docker-Daemon ist nicht erreichbar. Docker Desktop starten und das Skript erneut aufrufen.'
        }
    }

    if ($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
        $problems += 'node ist nicht im PATH. Node.js 20+ installieren (https://nodejs.org).'
    }
    if ($null -eq (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        $problems += 'pnpm ist nicht im PATH. Aktivieren mit: corepack enable  (oder: npm install -g pnpm)'
    }
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $java -and [string]::IsNullOrEmpty($env:JAVA_HOME)) {
        $problems += 'Kein JDK gefunden (java nicht im PATH, JAVA_HOME nicht gesetzt). JDK 21+ installieren.'
    }

    return $problems
}

# ----------------------------------------------------------------- database --
# ONE shared database for all operating modes (unlike the eportfolio model,
# which has one compose project per mode).

function Start-Db {
    $cfg = Get-DbConfig
    Write-Host 'Starte die Datenbank ...'
    & docker @Compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'docker compose up ist fehlgeschlagen (Meldung siehe oben).'
        return
    }
    Write-Host ('Warte auf Postgres (127.0.0.1:{0}) ...' -f $cfg.Port)
    for ($i = 0; $i -lt 15; $i++) {
        if (Invoke-Quiet 'docker' ($Compose + @('exec', '-T', 'postgres', 'pg_isready', '-U', $cfg.User, '-d', $cfg.Db))) {
            Write-Ok 'Postgres nimmt Verbindungen an.'
            return
        }
        Start-Sleep -Seconds 2
    }
    Write-Warn 'Postgres meldet sich nach 30 Sekunden nicht bereit - Logs pruefen (Menuepunkt 4).'
}

function Stop-Db {
    Write-Host 'Stoppe die Datenbank (Daten bleiben im Volume erhalten) ...'
    & docker @Compose stop
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Datenbank gestoppt.' } else { Write-Err 'Stoppen fehlgeschlagen (Meldung siehe oben).' }
}

function Show-DbStatus {
    & docker @Compose ps
}

# Follows the DB logs. Ctrl+C ends ONLY this view: while the log client runs,
# Ctrl+C is read as a plain key press (TreatControlCAsInput), then the client
# process tree is stopped. The container keeps running; the menu returns.
function Watch-DbLogs {
    Write-Host 'Folge den Postgres-Logs - Strg+C beendet nur die Anzeige, der Container laeuft weiter.' -ForegroundColor Yellow
    $prev = [Console]::TreatControlCAsInput
    [Console]::TreatControlCAsInput = $true
    $proc = $null
    try {
        $argLine = ConvertTo-ArgLine -Items ($Compose + @('logs', '--follow', '--tail=200', 'postgres'))
        $proc = Start-Process -FilePath 'docker' -ArgumentList $argLine -NoNewWindow -PassThru
        while (-not $proc.HasExited) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $ctrl = (($key.Modifiers -band [ConsoleModifiers]::Control) -ne 0)
                if ($ctrl -and $key.Key -eq [ConsoleKey]::C) { break }
            }
            Start-Sleep -Milliseconds 200
        }
    } finally {
        if ($null -ne $proc -and -not $proc.HasExited) {
            # docker.exe spawns the compose plugin as a child - stop the tree.
            [void](Invoke-Quiet 'taskkill.exe' @('/PID', "$($proc.Id)", '/T', '/F'))
        }
        [Console]::TreatControlCAsInput = $prev
    }
    Write-Host ''
    Write-Host 'Log-Anzeige beendet - der Container laeuft weiter.'
}

function Open-DbShell {
    $cfg = Get-DbConfig
    Write-Host ('Oeffne psql als "{0}" in Datenbank "{1}" - verlassen mit \q' -f $cfg.User, $cfg.Db)
    # Interactive, no pipe/redirect: psql needs the terminal, Ctrl+C cancels queries.
    & docker @Compose exec postgres psql -U $cfg.User -d $cfg.Db
    if ($LASTEXITCODE -ne 0) {
        Write-Warn 'psql hat sich mit Fehler beendet - laeuft der Container? (Menuepunkte 1 und 3)'
    }
}

function Remove-Db {
    Write-Host ''
    Write-Host 'WARNUNG: Entfernt den Postgres-Container UND das Volume tishreen-pgdata' -ForegroundColor Red
    Write-Host '(Docker-Name: infra_tishreen-pgdata). Alle lokalen DB-Daten gehen verloren -' -ForegroundColor Red
    Write-Host 'die Datenbank ist fuer ALLE Betriebsarten dieselbe!' -ForegroundColor Red
    $answer = Read-Host 'Zum Bestaetigen JA in Grossbuchstaben eingeben'
    if ($answer -cne 'JA') {
        Write-Host 'Abgebrochen - nichts entfernt.'
        return
    }
    & docker @Compose down --volumes --remove-orphans
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Container und Volume entfernt.' } else { Write-Err 'Entfernen fehlgeschlagen (Meldung siehe oben).' }
}

# -------------------------------------------------------------- api and web --

function Start-Api {
    $m = Get-ModeConfig
    if ($script:Mode -eq 'dev') {
        Write-Host ('Starte die API (mvnw spring-boot:run, Profil "dev") in einem neuen Fenster (http://localhost:{0}) ...' -f $m.ApiPort)
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/k mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev' -WorkingDirectory $ApiDir
        return
    }
    $jar = Find-ApiJar
    if ($null -eq $jar) {
        Write-Warn 'Kein Jar in api\target gefunden - erst das Artefakt bauen (Menuepunkt 8).'
        return
    }
    if ($script:Mode -eq 'prod') {
        Write-Warn 'Profil prod braucht DB_URL/DB_USER/DB_PASSWORD auf eine saubere Datenbank und echte Werte.'
        Write-Warn 'Gegen die Dev-DB (mit Dev-Seed V900) bricht Flyway absichtlich ab - Fail-Fast, kein Skript-Fehler.'
    }
    Write-Host ('Starte {0} (Profil "{1}") in einem neuen Fenster (http://localhost:{2}) ...' -f $jar.Name, $m.Profil, $m.ApiPort)
    $cmdLine = ('/k java -jar target\{0} --spring.profiles.active={1} --server.port={2}' -f $jar.Name, $m.Profil, $m.ApiPort)
    Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdLine -WorkingDirectory $ApiDir
}

# Builds the delivery artifacts for NEARPROD and PROD: the Spring Boot fat jar
# and the web production build. DEV works straight on the sources.
function Invoke-ArtifactBuild {
    if ($script:Mode -eq 'dev') {
        Write-Warn 'In DEV nicht noetig: mvnw spring-boot:run und der Vite-Dev-Server arbeiten direkt auf dem Quellcode.'
        return
    }
    Write-Host 'Baue das API-Jar (mvnw -DskipTests package) ...'
    Push-Location -LiteralPath $ApiDir
    try {
        & .\mvnw.cmd -DskipTests package
    } finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'API-Build fehlgeschlagen (Meldung siehe oben).'
        return
    }
    Write-Ok 'API-Jar gebaut.'
    Write-Host 'Baue das Frontend (pnpm build in apps\web) ...'
    Push-Location -LiteralPath $WebDir
    try {
        & pnpm build
    } finally {
        Pop-Location
    }
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Web-Build fertig.' } else { Write-Err 'Web-Build fehlgeschlagen (Meldung siehe oben).' }
}

function Invoke-ApiTests {
    Write-Host 'Starte mvnw verify (kann einige Minuten dauern) ...'
    Push-Location -LiteralPath $ApiDir
    try {
        & .\mvnw.cmd verify
    } finally {
        Pop-Location
    }
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Tests gruen.' } else { Write-Err 'Tests fehlgeschlagen (Meldung siehe oben).' }
}

function Start-Web {
    $m = Get-ModeConfig
    if ($script:Mode -eq 'dev') {
        Write-Host ('Starte den Vite-Dev-Server in einem neuen Fenster (http://localhost:{0}) ...' -f $m.WebPort)
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/k pnpm dev' -WorkingDirectory $WebDir
        return
    }
    $dist   = Join-Path $WebDir 'dist'
    $output = Join-Path $WebDir '.output'
    if (-not (Test-Path -LiteralPath $dist) -and -not (Test-Path -LiteralPath $output)) {
        Write-Warn 'Kein Web-Build gefunden (apps\web\dist) - erst das Artefakt bauen (Menuepunkt 8).'
        return
    }
    Write-Host ('Starte die Vorschau des gebauten Frontends in einem neuen Fenster (http://localhost:{0}) ...' -f $m.WebPort)
    Start-Process -FilePath 'cmd.exe' -ArgumentList ('/k pnpm preview --port {0}' -f $m.WebPort) -WorkingDirectory $WebDir
}

function Invoke-TurboTask {
    param([string]$Task)
    Write-Host ('Starte "pnpm {0}" (Turbo, alle Pakete) ...' -f $Task)
    Push-Location -LiteralPath $RepoRoot
    try {
        & pnpm $Task
    } finally {
        Pop-Location
    }
    if ($LASTEXITCODE -eq 0) { Write-Ok ('{0} gruen.' -f $Task) } else { Write-Err ('{0} fehlgeschlagen (Meldung siehe oben).' -f $Task) }
}

function Start-Mobile {
    if (-not (Test-Path -LiteralPath $MobileDir)) {
        Write-Warn 'apps\mobile existiert nicht in diesem Checkout.'
        return
    }
    Write-Host 'Starte den Expo-Dev-Server (apps\mobile) in einem neuen Fenster ...'
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/k pnpm dev' -WorkingDirectory $MobileDir
}

# ------------------------------------------------------------------- health --

function Show-Health {
    $cfg = Get-DbConfig
    $m = Get-ModeConfig
    Write-Host ''
    Write-Host ('Gesundheits-Check ({0}):' -f $m.Label)
    if (-not (Invoke-Quiet 'docker' @('info'))) {
        Write-Err 'Docker-Daemon nicht erreichbar - Docker Desktop starten.'
    } elseif (Invoke-Quiet 'docker' ($Compose + @('exec', '-T', 'postgres', 'pg_isready', '-U', $cfg.User, '-d', $cfg.Db))) {
        Write-Ok ('Postgres bereit (127.0.0.1:{0}).' -f $cfg.Port)
    } else {
        Write-Err 'Postgres nicht bereit - Container gestartet? (Menuepunkte 1 und 3)'
    }
    Show-HttpHealth -Name 'API' -Url ('http://localhost:{0}/actuator/health' -f $m.ApiPort) -Port $m.ApiPort
    Show-HttpHealth -Name 'Web' -Url ('http://localhost:{0}/' -f $m.WebPort) -Port $m.WebPort
}

# A 4xx answer counts as a sign of life (the server responded), not an outage.
function Show-HttpHealth {
    param([string]$Name, [string]$Url, [int]$Port)
    $status = Get-HttpStatus -Url $Url -Port $Port
    if ($null -eq $status) {
        Write-Err ('{0} nicht erreichbar ({1}).' -f $Name, $Url)
    } elseif ($status -eq -1) {
        Write-Ok ('{0}: Port {1} offen (TCP-Check, da curl.exe fehlt - kein HTTP-Status verfuegbar).' -f $Name, $Port)
    } elseif ($status -eq 200) {
        Write-Ok ('{0} erreichbar (HTTP 200, {1}).' -f $Name, $Url)
    } elseif ($status -eq 503) {
        Write-Warn ('{0} erreichbar, meldet aber Status DOWN (HTTP 503) - Datenbank pruefen.' -f $Name)
    } elseif ($status -ge 400 -and $status -lt 500) {
        Write-Ok ('{0} erreichbar (HTTP {1} - Lebenszeichen).' -f $Name, $status)
    } else {
        Write-Warn ('{0} antwortet mit HTTP {1}.' -f $Name, $status)
    }
}

# --------------------------------------------------------------------- menu --

function Select-Mode {
    Write-Host ''
    Write-Host 'Betriebsart waehlen:'
    $keys = @($Modes.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $m = $Modes[$keys[$i]]
        Write-Host ('  {0}  {1,-32} Profil {2}, API {3}, Web {4}' -f ($i + 1), $m.Label, $m.Profil, $m.ApiPort, $m.WebPort)
        Write-Host ('       {0}' -f $m.Hinweis) -ForegroundColor DarkGray
    }
    $answer = Read-Host 'Nummer'
    $index = 0
    if ([int]::TryParse($answer, [ref]$index) -and $index -ge 1 -and $index -le $keys.Count) {
        $script:Mode = $keys[$index - 1]
        Write-Ok ('Betriebsart ist jetzt {0}.' -f (Get-ModeConfig).Label)
    } else {
        Write-Host 'Unveraendert.'
    }
}

function Show-Menu {
    $cfg = Get-DbConfig
    $m = Get-ModeConfig
    Write-Host ''
    Write-Host '=== Tishreen Mall - lokaler Dev-Stack =========================' -ForegroundColor Cyan
    Write-Host ('    Betriebsart: {0}  (Spring-Profil {1})' -f $m.Label, $m.Profil) -ForegroundColor Green
    Write-Host ('    Postgres 127.0.0.1:{0} | API http://localhost:{1} | Web http://localhost:{2}' -f $cfg.Port, $m.ApiPort, $m.WebPort)
    Write-Host ''
    Write-Host '    b  Betriebsart wechseln  (dev / nearprod / prod)'
    Write-Host ''
    Write-Host '  Datenbank (Docker, eine gemeinsame fuer alle Betriebsarten)'
    Write-Host '    1  Starten'
    Write-Host '    2  Stoppen'
    Write-Host '    3  Status'
    Write-Host '    4  Logs folgen          (Strg+C beendet nur die Anzeige)'
    Write-Host '    5  psql-Shell           (verlassen mit \q)'
    Write-Host '    6  Komplett entfernen   (inkl. Volume - Datenverlust!)'
    Write-Host '  API (Host)'
    Write-Host '    7  Starten              (dev: mvnw spring-boot:run | sonst: Jar; neues Fenster)'
    Write-Host '    8  Artefakte bauen      (API-Jar + Web-Build; fuer nearprod/prod)'
    Write-Host '    9  Tests: mvnw verify'
    Write-Host '  Web (Host)'
    Write-Host '   10  Starten              (dev: Vite-Dev-Server | sonst: preview; neues Fenster)'
    Write-Host '   11  Lint      (Turbo)'
    Write-Host '   12  Typecheck (Turbo)'
    Write-Host '   13  Mobile: Expo starten (neues Fenster)'
    Write-Host '  Stack'
    Write-Host '   14  Gesundheit checken'
    Write-Host '    0  Beenden'
    Write-Host ''
}

# ---------------------------------------------------------------- main flow --

if ($Check) {
    Write-Host 'Pruefe Voraussetzungen ...'
    $problems = @(Test-Prerequisites)
    if ($problems.Count -eq 0) {
        Write-Ok 'Alle Voraussetzungen erfuellt.'
        exit 0
    }
    foreach ($p in $problems) { Write-Err $p }
    exit 1
}

# Guard against non-interactive use: Read-Host would return empty strings
# forever and the menu would spin in a tight loop.
if ([Console]::IsInputRedirected) {
    Write-Host 'tishreen.ps1 ist ein interaktives Menue und braucht eine echte Konsole.'
    Write-Host 'Fuer nicht-interaktive Aufrufe: .\tishreen.ps1 -Check'
    exit 1
}

Write-Host 'Pruefe Voraussetzungen ...'
$problems = @(Test-Prerequisites -OfferDockerStart)
if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Host 'Es fehlen Voraussetzungen fuer den Dev-Stack:' -ForegroundColor Red
    foreach ($p in $problems) { Write-Err $p }
    Write-Host ''
    Write-Host 'Bitte beheben und das Skript erneut starten.'
    exit 1
}
Write-Ok 'Alle Voraussetzungen erfuellt.'

$emptyInputs = 0
$done = $false
while (-not $done) {
    Show-Menu
    $choice = Read-Host 'Auswahl'
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $emptyInputs++
        if ($emptyInputs -ge 3) {
            Write-Host 'Mehrfach leere Eingabe - vermutlich keine interaktive Konsole. Beende.'
            exit 1
        }
        continue
    }
    $emptyInputs = 0
    switch ($choice.Trim()) {
        'b'  { Select-Mode }
        '1'  { Start-Db }
        '2'  { Stop-Db }
        '3'  { Show-DbStatus }
        '4'  { Watch-DbLogs }
        '5'  { Open-DbShell }
        '6'  { Remove-Db }
        '7'  { Start-Api }
        '8'  { Invoke-ArtifactBuild }
        '9'  { Invoke-ApiTests }
        '10' { Start-Web }
        '11' { Invoke-TurboTask -Task 'lint' }
        '12' { Invoke-TurboTask -Task 'typecheck' }
        '13' { Start-Mobile }
        '14' { Show-Health }
        '0'  { $done = $true }
        'q'  { $done = $true }
        default { Write-Warn ('Unbekannte Auswahl: {0}' -f $choice) }
    }
    if (-not $done) { Wait-Enter }
}
Write-Host 'Bis bald.'
exit 0
