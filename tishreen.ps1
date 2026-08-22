# Tishreen Mall: Steuerung des lokalen Dev-Stacks.
#
# Aufruf ohne Parameter oeffnet das Menue:
#   .\tishreen.ps1
# Mit vorgewaehlter Betriebsart:
#   .\tishreen.ps1 -Mode nearprod
# Nur die Voraussetzungen pruefen (nicht-interaktiv, Exit-Code 0/1):
#   .\tishreen.ps1 -Check
#
# Der Text ist bewusst frei von Umlauten: Windows PowerShell 5.1 liest eine
# UTF-8-Datei ohne BOM als ANSI und wuerde sie zerlegen.
#
# Drei Betriebsarten, drei getrennte Compose-Projekte fuer die Datenbank
# (tishreen-dev, tishreen-nearprod, tishreen-prod). Sie haben eigene Ports
# und eigene Volumes und koennen deshalb nebeneinander laufen; sie teilen
# sich insbesondere KEINE Datenbank. Anders als beim Vorbild eportfolio.ps1
# laufen API und Web auf dem Host (docs/09 Abschnitt 4): Docker dient nur
# der Datenbank, das Ziel-Deployment ist nginx + systemd (docs/09
# Abschnitt 5), nicht Container.
#
#   DEV       Quellcode-Betrieb: mvnw spring-boot:run, Vite-Dev-Server.
#             Profil dev. Zum Entwickeln.
#   NEARPROD  Gebautes Jar, gebautes Frontend (vite preview).
#             Profil dev. Prueft den Auslieferungsstand, nicht die
#             Produktivkonfiguration.
#   PROD      Dasselbe Jar, aber Profil prod: kein Swagger, kein Dev-Seed.
#             Laeuft gegen die eigene, saubere prod-Datenbank.
#
# Jede Betriebsart wird ausdruecklich benannt. "docker compose up" ohne -f
# scheitert mit "no configuration file provided"; das ist Absicht.

[CmdletBinding()]
param(
	[ValidateSet('dev', 'nearprod', 'prod')]
	[string]$Mode = 'dev',
	[switch]$Check
)

Set-StrictMode -Version 2.0
Set-Location -Path $PSScriptRoot

$BaseFile = 'infra\compose.base.yml'
$EnvFile  = 'infra\.env'

$Modes = [ordered]@{
	'dev' = @{
		Label      = 'DEV / Quellcode-Betrieb'
		Project    = 'tishreen-dev'
		File       = 'infra\compose.dev.yml'
		Profil     = 'dev'
		DbVar      = 'DEV_POSTGRES_PORT'
		DbDefault  = '5432'
		ApiVar     = 'DEV_API_PORT'
		ApiDefault = '8080'
		WebVar     = 'DEV_WEB_PORT'
		WebDefault = '3000'
		Hinweis    = 'Hot Reload: mvnw spring-boot:run und Vite-Dev-Server direkt auf dem Quellcode. Erster Start laedt Maven-Abhaengigkeiten, das dauert.'
	}
	'nearprod' = @{
		Label      = 'NEARPROD / Auslieferungsstand'
		Project    = 'tishreen-nearprod'
		File       = 'infra\compose.nearprod.yml'
		Profil     = 'dev'
		DbVar      = 'NEARPROD_POSTGRES_PORT'
		DbDefault  = '5532'
		ApiVar     = 'NEARPROD_API_PORT'
		ApiDefault = '8180'
		WebVar     = 'NEARPROD_WEB_PORT'
		WebDefault = '3100'
		Hinweis    = 'Gebautes Jar und gebautes Frontend (vite preview), aber weiterhin Profil dev: eigene Datenbank mit Dev-Seed, Swagger an. Prueft den Auslieferungsstand, nicht die Produktivkonfiguration.'
	}
	'prod' = @{
		Label      = 'PROD / Produktivkonfiguration'
		Project    = 'tishreen-prod'
		File       = 'infra\compose.prod.yml'
		Profil     = 'prod'
		DbVar      = 'PROD_POSTGRES_PORT'
		DbDefault  = '5632'
		ApiVar     = 'PROD_API_PORT'
		ApiDefault = '8280'
		WebVar     = 'PROD_WEB_PORT'
		WebDefault = '3200'
		Hinweis    = 'Dasselbe Jar, aber Profil prod: kein Swagger, kein Dev-Seed. Laeuft gegen die eigene, saubere prod-Datenbank (Flyway wendet nur V1 und V2 an).'
	}
}

$script:Mode = $Mode
$script:LastDockerExit = 0

# --------------------------------------------------------------------------
# Hilfsfunktionen
# --------------------------------------------------------------------------

function Get-Mode { return $Modes[$script:Mode] }

# Alle Aufrufe nennen beide Dateien und die Env-Datei. Der Projektname kommt
# aus dem "name" im Overlay, deshalb braucht es kein zusaetzliches -p.
function Get-ComposeArgs {
	$m = Get-Mode
	return @('-f', $BaseFile, '-f', $m['File'], '--env-file', $EnvFile)
}

function Write-Head {
	param([string]$Text)
	Write-Host ''
	Write-Host $Text -ForegroundColor Cyan
	Write-Host ('-' * $Text.Length) -ForegroundColor DarkGray
}

function Invoke-Docker {
	param([string[]]$Arguments)
	Write-Host ''
	Write-Host "> docker $($Arguments -join ' ')" -ForegroundColor DarkGray
	# Kein Pipe und keine Umleitung: "compose exec" braucht die Konsole
	# unveraendert, sonst gibt es kein Terminal und kein Strg+C.
	& docker @Arguments
	$script:LastDockerExit = $LASTEXITCODE
	if ($script:LastDockerExit -ne 0) {
		Write-Host ''
		Write-Host "Docker meldet Exit-Code $($script:LastDockerExit)." -ForegroundColor Red
	}
}

function Invoke-Compose {
	param([string[]]$Arguments)
	Invoke-Docker ((@('compose') + (Get-ComposeArgs)) + $Arguments)
}

# Wie Invoke-Docker, nur ohne jede Ausgabe; liefert $true bei Exit-Code 0.
# Fuer Sonden (Daemon da? Postgres bereit?), deren Fehlermeldungen nur
# Rauschen waeren.
function Invoke-Quiet {
	param([string]$File, [string[]]$Arguments)
	try {
		& $File @Arguments *> $null
		return ($LASTEXITCODE -eq 0)
	} catch {
		return $false
	}
}

function Confirm-Action {
	param([string]$Message)
	Write-Host ''
	Write-Host $Message -ForegroundColor Yellow
	$answer = Read-Host 'Wirklich ausfuehren? [j/N]'
	return ($answer -eq 'j' -or $answer -eq 'J')
}

# Liest einen Wert aus infra/.env. Sie ist die einzige Quelle der Ports und
# Zugangsdaten und wird nicht eingecheckt; die Defaults spiegeln die
# Compose-Dateien. POSTGRES_PASSWORD wird nur als Umgebungsvariable an die
# API weitergereicht und nirgends angezeigt.
function Get-EnvValue {
	param([string]$Name, [string]$Default)
	$envPath = Join-Path $PSScriptRoot $EnvFile
	if (Test-Path $envPath) {
		foreach ($line in Get-Content -Path $envPath) {
			if ($line -match "^\s*$([regex]::Escape($Name))\s*=\s*(.*)$") {
				$value = $Matches[1].Trim()
				if ($value -ne '') { return $value }
			}
		}
	}
	return $Default
}

function Get-ApiPort {
	$m = Get-Mode
	return Get-EnvValue -Name $m['ApiVar'] -Default $m['ApiDefault']
}

function Get-WebPort {
	$m = Get-Mode
	return Get-EnvValue -Name $m['WebVar'] -Default $m['WebDefault']
}

function Get-DbPort {
	$m = Get-Mode
	return Get-EnvValue -Name $m['DbVar'] -Default $m['DbDefault']
}

function Get-DbUser { return Get-EnvValue -Name 'POSTGRES_USER' -Default 'tishreen' }
function Get-DbName { return Get-EnvValue -Name 'POSTGRES_DB' -Default 'tishreen' }

# Geprueft wird mit curl.exe, nicht mit Invoke-WebRequest. Grund: gegen den
# Vite-Dev-Server laeuft der .NET-Webstack in einen Timeout, waehrend curl.exe
# im selben Prozess HTTP 200 bekommt. Invoke-WebRequest meldete also "nicht
# erreichbar" fuer eine laufende Oberflaeche, und ein Fehlalarm ist schlimmer
# als keine Pruefung. curl.exe liegt seit Windows 10 1803 im System; fehlt es
# doch, faellt die Funktion zurueck.
function Test-Endpoint {
	param([string]$Label, [string]$Url)

	$status = $null
	if ($null -ne (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
		$code = & curl.exe -s -o NUL -m 5 -w '%{http_code}' $Url
		# curl liefert 000, wenn gar keine Antwort kam.
		if ($LASTEXITCODE -eq 0 -and $code -ne '000') { $status = [int]$code }
	} else {
		try {
			$status = [int](Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5).StatusCode
		} catch {
			$webException = $_.Exception -as [System.Net.WebException]
			if ($null -ne $webException -and $null -ne $webException.Response) {
				$status = [int]$webException.Response.StatusCode
			}
		}
	}

	if ($null -eq $status) {
		Write-Host ("  {0,-30} nicht erreichbar" -f $Label) -ForegroundColor Red
	} elseif ($status -ge 200 -and $status -lt 400) {
		Write-Host ("  {0,-30} HTTP {1}" -f $Label, $status) -ForegroundColor Green
	} else {
		# Ein 4xx ist eine Antwort und damit ein Lebenszeichen, kein Ausfall.
		Write-Host ("  {0,-30} HTTP {1}" -f $Label, $status) -ForegroundColor Yellow
	}
}

# Bietet an, Docker Desktop zu starten, und wartet auf den Daemon. Auf dieser
# Maschine startet Docker Desktop nicht automatisch.
function Request-DockerDesktopStart {
	$exe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
	if (-not (Test-Path $exe)) { return $false }
	Write-Host ''
	Write-Host 'Docker Desktop ist installiert, der Daemon antwortet aber nicht.'
	$answer = Read-Host 'Docker Desktop jetzt starten? [j/N]'
	if ($answer -ne 'j' -and $answer -ne 'J') { return $false }
	Start-Process -FilePath $exe
	Write-Host 'Warte auf den Docker-Daemon (bis zu 90 Sekunden) ...'
	for ($i = 0; $i -lt 30; $i++) {
		Start-Sleep -Seconds 3
		if (Invoke-Quiet 'docker' @('info')) {
			Write-Host 'Docker-Daemon erreichbar.' -ForegroundColor Green
			return $true
		}
	}
	return $false
}

# Prueft die Voraussetzungen. Jede fehlende Voraussetzung bekommt ihre eigene
# klare Meldung; sonst kosten diese Fehler spaeter eine schwer lesbare Meldung
# aus Compose oder Maven.
function Test-Voraussetzungen {
	param([switch]$OfferDockerStart)

	if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
		Write-Host 'Docker ist nicht installiert oder nicht im PATH.' -ForegroundColor Red
		return $false
	}

	$ok = $true

	$daemonUp = Invoke-Quiet 'docker' @('info')
	if (-not $daemonUp -and $OfferDockerStart) {
		$daemonUp = Request-DockerDesktopStart
	}
	if (-not $daemonUp) {
		Write-Host 'Docker antwortet nicht. Laeuft Docker Desktop?' -ForegroundColor Red
		$ok = $false
	}

	if (-not (Invoke-Quiet 'docker' @('compose', 'version'))) {
		Write-Host 'Docker Compose v2 fehlt (docker compose version schlaegt fehl).' -ForegroundColor Red
		$ok = $false
	}

	foreach ($file in @($BaseFile, 'infra\compose.dev.yml', 'infra\compose.nearprod.yml', 'infra\compose.prod.yml')) {
		if (-not (Test-Path (Join-Path $PSScriptRoot $file))) {
			Write-Host "Es fehlt $file." -ForegroundColor Red
			$ok = $false
		}
	}

	if (-not (Test-Path (Join-Path $PSScriptRoot $EnvFile))) {
		Write-Host 'Es gibt keine infra\.env. Anlegen mit: Copy-Item infra\.env.example infra\.env' -ForegroundColor Red
		$ok = $false
	}

	if ($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
		Write-Host 'node ist nicht im PATH. Node.js 20+ installieren (https://nodejs.org).' -ForegroundColor Red
		$ok = $false
	}

	if ($null -eq (Get-Command pnpm -ErrorAction SilentlyContinue)) {
		Write-Host 'pnpm ist nicht im PATH. Aktivieren mit: corepack enable' -ForegroundColor Red
		$ok = $false
	}

	$java = Get-Command java -ErrorAction SilentlyContinue
	if ($null -eq $java -and [string]::IsNullOrEmpty($env:JAVA_HOME)) {
		Write-Host 'Kein JDK gefunden (java nicht im PATH, JAVA_HOME nicht gesetzt). JDK 21+ installieren.' -ForegroundColor Red
		$ok = $false
	}

	return $ok
}

# Neuestes Spring-Boot-Jar in api\target (das .jar.original und Hilfs-Jars
# zaehlen nicht). $null, wenn noch nichts gebaut wurde.
function Find-ApiJar {
	$targetDir = Join-Path $PSScriptRoot 'api\target'
	if (-not (Test-Path $targetDir)) { return $null }
	$jars = @(Get-ChildItem -Path $targetDir -Filter '*.jar' |
		Where-Object { $_.Name -notlike '*-sources.jar' -and $_.Name -notlike '*-javadoc.jar' } |
		Sort-Object -Property LastWriteTime -Descending)
	if ($jars.Count -eq 0) { return $null }
	return $jars[0]
}

function Show-Adressen {
	$webPort = Get-WebPort
	$apiPort = Get-ApiPort
	$m = Get-Mode
	Write-Host ''
	Write-Host "Erreichbar unter ($($m['Label'])):" -ForegroundColor Cyan
	Write-Host "  Oberflaeche   http://localhost:$webPort"
	Write-Host "  API           http://localhost:$apiPort/api/v1"
	if ($m['Profil'] -eq 'dev') {
		Write-Host "  Swagger-UI    http://localhost:$apiPort/swagger-ui.html"
		Write-Host "  OpenAPI       http://localhost:$apiPort/api/v1/docs"
	} else {
		Write-Host "  Swagger-UI    im Profil prod abgeschaltet"
	}
	Write-Host "  Health        http://localhost:$apiPort/actuator/health"
	Write-Host "  Postgres      127.0.0.1:$(Get-DbPort)  (Projekt $($m['Project']), eigene Datenbank)"
}

# --------------------------------------------------------------------------
# Aktionen
# --------------------------------------------------------------------------

function Select-Betriebsart {
	Write-Head 'Betriebsart waehlen'
	$keys = @($Modes.Keys)
	for ($i = 0; $i -lt $keys.Count; $i++) {
		$m = $Modes[$keys[$i]]
		Write-Host ("  {0}  {1,-34} Projekt {2}, Profil {3}" -f ($i + 1), $m['Label'], $m['Project'], $m['Profil'])
	}
	$answer = Read-Host 'Nummer'
	$index = 0
	if ([int]::TryParse($answer, [ref]$index) -and $index -ge 1 -and $index -le $keys.Count) {
		$script:Mode = $keys[$index - 1]
		Write-Host ''
		Write-Host "Betriebsart ist jetzt $((Get-Mode)['Label'])." -ForegroundColor Green
	} else {
		Write-Host 'Unveraendert.' -ForegroundColor DarkGray
	}
}

function Start-Datenbank {
	Invoke-Compose @('up', '-d')
	if ($script:LastDockerExit -ne 0) { return }
	Write-Host ''
	Write-Host "Warte auf Postgres (127.0.0.1:$(Get-DbPort)) ..." -ForegroundColor DarkGray
	for ($i = 0; $i -lt 15; $i++) {
		if (Invoke-Quiet 'docker' ((@('compose') + (Get-ComposeArgs)) + @('exec', '-T', 'postgres', 'pg_isready', '-U', (Get-DbUser), '-d', (Get-DbName)))) {
			Write-Host 'Postgres nimmt Verbindungen an.' -ForegroundColor Green
			return
		}
		Start-Sleep -Seconds 2
	}
	Write-Host 'Postgres meldet sich nicht bereit. Logs pruefen (Menuepunkt 9).' -ForegroundColor Yellow
}

# Baut die Artefakte fuer NEARPROD und PROD: das Spring-Boot-Jar und den
# Web-Produktionsbuild. DEV arbeitet direkt auf dem Quellcode.
function Invoke-ArtefakteBauen {
	param([switch]$Clean)

	if ($script:Mode -eq 'dev') {
		Write-Host 'In DEV gibt es nichts zu bauen: spring-boot:run und der Vite-Dev-Server' -ForegroundColor Yellow
		Write-Host 'arbeiten direkt auf dem Quellcode. Bauen lohnt fuer nearprod und prod.' -ForegroundColor Yellow
		return $true
	}

	$mvnArgs = @()
	if ($Clean) { $mvnArgs += 'clean' }
	$mvnArgs += @('package', '-DskipTests')

	Push-Location (Join-Path $PSScriptRoot 'api')
	try {
		Write-Host ''
		Write-Host "> .\mvnw.cmd $($mvnArgs -join ' ')" -ForegroundColor DarkGray
		& .\mvnw.cmd @mvnArgs
	} finally {
		Pop-Location
	}
	if ($LASTEXITCODE -ne 0) {
		Write-Host 'API-Build fehlgeschlagen.' -ForegroundColor Red
		return $false
	}

	Push-Location (Join-Path $PSScriptRoot 'apps\web')
	try {
		Write-Host ''
		Write-Host '> pnpm build' -ForegroundColor DarkGray
		& pnpm build
	} finally {
		Pop-Location
	}
	if ($LASTEXITCODE -ne 0) {
		Write-Host 'Web-Build fehlgeschlagen.' -ForegroundColor Red
		return $false
	}

	Write-Host ''
	Write-Host 'Artefakte gebaut: api\target (Jar) und apps\web (Web-Build).' -ForegroundColor Green
	return $true
}

function Start-Api {
	$m = Get-Mode
	$apiPort = Get-ApiPort
	# Die API bekommt die Datenbank IHRER Betriebsart ueber die Umgebung
	# (env-first, docs/09 Konfiguration). Das Passwort steht damit weder in
	# der Anzeige noch auf der Kommandozeile des neuen Fensters.
	$env:DB_URL      = "jdbc:postgresql://localhost:$(Get-DbPort)/$(Get-DbName)"
	$env:DB_USER     = Get-DbUser
	$env:DB_PASSWORD = Get-EnvValue -Name 'POSTGRES_PASSWORD' -Default 'tishreen'
	try {
		if ($script:Mode -eq 'dev') {
			$line = "/k mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=dev -Dspring-boot.run.arguments=--server.port=$apiPort"
			Write-Host ''
			Write-Host "> cmd $line   (neues Fenster, api\)" -ForegroundColor DarkGray
			Start-Process -FilePath 'cmd.exe' -ArgumentList $line -WorkingDirectory (Join-Path $PSScriptRoot 'api')
			return
		}
		$jar = Find-ApiJar
		if ($null -eq $jar) {
			Write-Host 'Kein Jar in api\target. Erst Artefakte bauen (Menuepunkt 4).' -ForegroundColor Yellow
			return
		}
		$line = "/k java -jar target\$($jar.Name) --spring.profiles.active=$($m['Profil']) --server.port=$apiPort"
		Write-Host ''
		Write-Host "> cmd $line   (neues Fenster, api\)" -ForegroundColor DarkGray
		Start-Process -FilePath 'cmd.exe' -ArgumentList $line -WorkingDirectory (Join-Path $PSScriptRoot 'api')
	} finally {
		Remove-Item Env:DB_URL, Env:DB_USER, Env:DB_PASSWORD -ErrorAction SilentlyContinue
	}
}

function Start-Web {
	$webPort = Get-WebPort
	if ($script:Mode -eq 'dev') {
		# Der Port kommt hier aus apps/web/package.json ("vite dev --port 3000");
		# DEV_WEB_PORT in der .env muss dazu passen.
		Write-Host ''
		Write-Host '> cmd /k pnpm dev   (neues Fenster, apps\web)' -ForegroundColor DarkGray
		Start-Process -FilePath 'cmd.exe' -ArgumentList '/k pnpm dev' -WorkingDirectory (Join-Path $PSScriptRoot 'apps\web')
		return
	}
	$dist   = Join-Path $PSScriptRoot 'apps\web\dist'
	$output = Join-Path $PSScriptRoot 'apps\web\.output'
	if (-not (Test-Path $dist) -and -not (Test-Path $output)) {
		Write-Host 'Kein Web-Build in apps\web. Erst Artefakte bauen (Menuepunkt 4).' -ForegroundColor Yellow
		return
	}
	$line = "/k pnpm preview --port $webPort"
	Write-Host ''
	Write-Host "> cmd $line   (neues Fenster, apps\web)" -ForegroundColor DarkGray
	Start-Process -FilePath 'cmd.exe' -ArgumentList $line -WorkingDirectory (Join-Path $PSScriptRoot 'apps\web')
}

function Start-Betriebsart {
	param([switch]$Build)
	$m = Get-Mode
	Write-Head "$($m['Label']) starten"
	Write-Host $m['Hinweis'] -ForegroundColor DarkGray

	if ($Build) {
		if (-not (Invoke-ArtefakteBauen)) { return }
	}

	Start-Datenbank
	if ($script:LastDockerExit -ne 0) { return }
	Start-Api
	Start-Web
	Show-Adressen
}

function Show-Status {
	Write-Head "Status: $((Get-Mode)['Label'])"
	Invoke-Compose @('ps', '--format', 'table {{.Name}}\t{{.Status}}\t{{.Ports}}')
	Write-Host ''
	Write-Host 'API und Web laufen auf dem Host in eigenen Fenstern; ihren Zustand' -ForegroundColor DarkGray
	Write-Host 'zeigt Menuepunkt 8 (Gesundheit pruefen).' -ForegroundColor DarkGray
}

function Show-StatusAlle {
	Write-Head 'Status aller Betriebsarten'
	Invoke-Docker @('ps', '--filter', 'name=tishreen-', '--format', 'table {{.Names}}\t{{.Status}}\t{{.Ports}}')
}

function Test-Gesundheit {
	$webPort = Get-WebPort
	$apiPort = Get-ApiPort
	$m = Get-Mode
	Write-Head "Gesundheit: $($m['Label'])"
	if (Invoke-Quiet 'docker' ((@('compose') + (Get-ComposeArgs)) + @('exec', '-T', 'postgres', 'pg_isready', '-U', (Get-DbUser), '-d', (Get-DbName)))) {
		Write-Host ("  {0,-30} bereit (127.0.0.1:{1})" -f 'Postgres', (Get-DbPort)) -ForegroundColor Green
	} else {
		Write-Host ("  {0,-30} nicht bereit (Menuepunkt 3)" -f 'Postgres') -ForegroundColor Red
	}
	Test-Endpoint -Label 'Oberflaeche' -Url "http://localhost:$webPort/"
	Test-Endpoint -Label 'API Health' -Url "http://localhost:$apiPort/actuator/health"
	if ($m['Profil'] -eq 'dev') {
		Test-Endpoint -Label 'OpenAPI-Dokument' -Url "http://localhost:$apiPort/api/v1/docs"
	} else {
		Write-Host '  OpenAPI-Dokument               im Profil prod abgeschaltet, 404 erwartet' -ForegroundColor DarkGray
		Test-Endpoint -Label 'OpenAPI-Dokument' -Url "http://localhost:$apiPort/api/v1/docs"
	}
}

# Folgt den Datenbank-Logs. Strg+C beendet NUR diese Anzeige: solange der
# Log-Client laeuft, wird Strg+C als Tastendruck gelesen (TreatControlCAsInput)
# und dann nur der Client-Prozessbaum beendet. Der Container laeuft weiter,
# das Menue kommt zurueck. (Bewusste Abweichung vom Vorbild: bei direktem
# Aufruf wuerde Strg+C unter PS 5.1 auch das Skript beenden.)
function Watch-DbLogs {
	$logArgs = (@('compose') + (Get-ComposeArgs)) + @('logs', '-f', '--tail', '100', 'postgres')
	Write-Host ''
	Write-Host "> docker $($logArgs -join ' ')" -ForegroundColor DarkGray
	Write-Host 'Strg+C beendet nur die Anzeige, der Container laeuft weiter.' -ForegroundColor Yellow
	$prev = [Console]::TreatControlCAsInput
	[Console]::TreatControlCAsInput = $true
	$proc = $null
	try {
		$proc = Start-Process -FilePath 'docker' -ArgumentList ($logArgs -join ' ') -NoNewWindow -PassThru
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
			# docker.exe startet das Compose-Plugin als Kindprozess - den Baum beenden.
			Invoke-Quiet 'taskkill.exe' @('/PID', "$($proc.Id)", '/T', '/F') | Out-Null
		}
		[Console]::TreatControlCAsInput = $prev
	}
	Write-Host ''
	Write-Host 'Log-Anzeige beendet, der Container laeuft weiter.'
}

function Open-Psql {
	Write-Head "psql als $(Get-DbUser) in $(Get-DbName) ($((Get-Mode)['Label']))"
	Write-Host 'Jede Betriebsart hat ihre eigene Datenbank. Beenden mit \q' -ForegroundColor DarkGray
	Invoke-Compose @('exec', 'postgres', 'psql', '-U', (Get-DbUser), '-d', (Get-DbName))
}

function Invoke-ApiTests {
	Write-Head 'API-Tests auf dem Host'
	Write-Host 'Integrationstests nutzen Testcontainers und starten ihre eigene Datenbank.' -ForegroundColor DarkGray
	Push-Location (Join-Path $PSScriptRoot 'api')
	try {
		Write-Host ''
		Write-Host '> .\mvnw.cmd verify' -ForegroundColor DarkGray
		& .\mvnw.cmd verify
	} finally {
		Pop-Location
	}
}

function Invoke-WebTests {
	Write-Head 'Web-Tests auf dem Host'
	Push-Location (Join-Path $PSScriptRoot 'apps\web')
	try {
		Write-Host ''
		Write-Host '> pnpm test' -ForegroundColor DarkGray
		& pnpm test
	} finally {
		Pop-Location
	}
}

function Invoke-TurboTask {
	param([string]$Task)
	Write-Head "$Task auf dem Host (Turbo, alle Pakete)"
	Push-Location $PSScriptRoot
	try {
		Write-Host ''
		Write-Host "> pnpm $Task" -ForegroundColor DarkGray
		& pnpm $Task
	} finally {
		Pop-Location
	}
}

function Start-Mobile {
	Write-Head 'Mobile: Expo-Dev-Server'
	if (-not (Test-Path (Join-Path $PSScriptRoot 'apps\mobile'))) {
		Write-Host 'apps\mobile existiert nicht in diesem Checkout.' -ForegroundColor Yellow
		return
	}
	Write-Host ''
	Write-Host '> cmd /k pnpm dev   (neues Fenster, apps\mobile)' -ForegroundColor DarkGray
	Start-Process -FilePath 'cmd.exe' -ArgumentList '/k pnpm dev' -WorkingDirectory (Join-Path $PSScriptRoot 'apps\mobile')
}

function Remove-Betriebsart {
	$m = Get-Mode
	Write-Head "$($m['Label']) vollstaendig entfernen"
	Write-Host "Das loescht Container und Volume des Projekts $($m['Project']):" -ForegroundColor Yellow
	Write-Host '  - den Datenbankinhalt dieser Betriebsart'
	Write-Host 'Die anderen beiden Betriebsarten bleiben unberuehrt.'
	if (Confirm-Action 'Daten dieser Betriebsart sind danach weg.') {
		Invoke-Compose @('down', '-v', '--remove-orphans')
	}
}

function Remove-Alles {
	Write-Head 'Alle drei Betriebsarten vollstaendig entfernen'
	Write-Host 'Das loescht Container und Volumes aller drei Projekte:' -ForegroundColor Yellow
	Write-Host '  - drei Datenbankinhalte (tishreen-dev, tishreen-nearprod, tishreen-prod)'
	Write-Host 'Andere Docker-Projekte bleiben unberuehrt.'
	if (-not (Confirm-Action 'Es bleibt nichts uebrig.')) { return }

	$merken = $script:Mode
	foreach ($key in @($Modes.Keys)) {
		$script:Mode = $key
		Invoke-Compose @('down', '-v', '--remove-orphans')
	}
	$script:Mode = $merken
	Write-Host ''
	Write-Host 'Fertig.' -ForegroundColor Green
}

# --------------------------------------------------------------------------
# Menue
# --------------------------------------------------------------------------

function Show-Menu {
	$m = Get-Mode
	Write-Host ''
	Write-Host '=====================================================' -ForegroundColor Cyan
	Write-Host ' Tishreen Mall: Steuerung des lokalen Dev-Stacks' -ForegroundColor Cyan
	Write-Host '=====================================================' -ForegroundColor Cyan
	Write-Host ''
	Write-Host (" Betriebsart : {0}" -f $m['Label']) -ForegroundColor Green
	Write-Host ("               Projekt {0}, Spring-Profil {1}, API {2}, Oberflaeche {3}, Postgres {4}" -f $m['Project'], $m['Profil'], (Get-ApiPort), (Get-WebPort), (Get-DbPort)) -ForegroundColor DarkGray
	Write-Host ''
	Write-Host '   b  Betriebsart wechseln' -ForegroundColor White
	Write-Host ''
	Write-Host ' Starten und bauen                        (gilt fuer die Betriebsart oben)' -ForegroundColor White
	Write-Host '   1  Starten                       (Datenbank + API + Web)'
	Write-Host '   2  Neu bauen und starten         (Artefakte vorher neu bauen)'
	Write-Host '   3  Nur die Datenbank starten'
	Write-Host '   4  Artefakte bauen, ohne zu starten   (Jar + Web-Build fuer nearprod/prod)'
	Write-Host '   5  Artefakte sauber neu bauen    (mvnw clean package, bei kaputtem target\)'
	Write-Host ''
	Write-Host ' Beobachten' -ForegroundColor White
	Write-Host '   6  Status'
	Write-Host '   7  Status ALLER Betriebsarten'
	Write-Host '   8  Gesundheit pruefen            (Postgres, Oberflaeche, Health, OpenAPI)'
	Write-Host '   9  Logs folgen: Datenbank        (Strg+C beendet nur die Anzeige)'
	Write-Host '      API und Web loggen in ihren eigenen Fenstern.' -ForegroundColor DarkGray
	Write-Host ''
	Write-Host ' Arbeiten' -ForegroundColor White
	Write-Host '  10  psql in der Datenbank'
	Write-Host '  11  API-Tests auf dem Host        (.\mvnw.cmd verify, Testcontainers)'
	Write-Host '  12  Web-Tests auf dem Host        (pnpm test in apps\web, Vitest)'
	Write-Host '  13  Lint auf dem Host             (pnpm lint ueber Turbo)'
	Write-Host '  14  Typecheck auf dem Host        (pnpm typecheck ueber Turbo)'
	Write-Host '  15  Format auf dem Host           (pnpm format ueber Turbo, Prettier)'
	Write-Host '  16  Mobile: Expo-Dev-Server       (neues Fenster)'
	Write-Host ''
	Write-Host ' Aufraeumen' -ForegroundColor White
	Write-Host '  17  Stoppen                       (Container und Daten bleiben)'
	Write-Host '  18  Container entfernen           (Volumes bleiben erhalten)'
	Write-Host '  19  Diese Betriebsart entfernen   [inkl. ihrer Datenbank]'
	Write-Host '  20  ALLE drei Betriebsarten entfernen  [Container und Volumes]'
	Write-Host ''
	Write-Host '   0  Beenden' -ForegroundColor White
	Write-Host ''
}

if ($Check) {
	if (Test-Voraussetzungen) {
		Write-Host 'Alle Voraussetzungen erfuellt.' -ForegroundColor Green
		exit 0
	}
	exit 1
}

# Schutz gegen einen nicht-interaktiven Aufruf: kommt die Eingabe aus einer
# Datei oder einer Pipeline, liefert Read-Host am Ende endlos leere Zeilen,
# und das Menue liefe fuer immer.
if ([Console]::IsInputRedirected) {
	Write-Host 'tishreen.ps1 ist ein interaktives Menue und braucht eine echte Konsole.'
	Write-Host 'Fuer nicht-interaktive Aufrufe: .\tishreen.ps1 -Check'
	exit 1
}

if (-not (Test-Voraussetzungen -OfferDockerStart)) {
	Write-Host ''
	Write-Host 'Abgebrochen.' -ForegroundColor Red
	exit 1
}

$running = $true
$leereEingaben = 0

while ($running) {
	Show-Menu
	$choice = Read-Host 'Auswahl'

	if ([string]::IsNullOrWhiteSpace($choice)) {
		$leereEingaben++
		if ($leereEingaben -ge 3) {
			Write-Host ''
			Write-Host 'Keine Eingabe. Beendet.' -ForegroundColor Yellow
			break
		}
		continue
	}
	$leereEingaben = 0

	switch ($choice.Trim().ToLower()) {
		'b'  { Select-Betriebsart }
		'1'  { Start-Betriebsart }
		'2'  { Start-Betriebsart -Build }
		'3'  { Write-Head 'Nur die Datenbank starten'; Start-Datenbank }
		'4'  { Write-Head 'Artefakte bauen, ohne zu starten'; Invoke-ArtefakteBauen | Out-Null }
		'5'  { Write-Head 'Artefakte sauber neu bauen'; Invoke-ArtefakteBauen -Clean | Out-Null }
		'6'  { Show-Status }
		'7'  { Show-StatusAlle }
		'8'  { Test-Gesundheit }
		'9'  { Watch-DbLogs }
		'10' { Open-Psql }
		'11' { Invoke-ApiTests }
		'12' { Invoke-WebTests }
		'13' { Invoke-TurboTask -Task 'lint' }
		'14' { Invoke-TurboTask -Task 'typecheck' }
		'15' { Invoke-TurboTask -Task 'format' }
		'16' { Start-Mobile }
		'17' { Write-Head 'Stoppen'; Invoke-Compose @('stop') }
		'18' { Write-Head 'Container entfernen'; Invoke-Compose @('down', '--remove-orphans') }
		'19' { Remove-Betriebsart }
		'20' { Remove-Alles }
		'0'  { $running = $false }
		default { Write-Host ''; Write-Host "Unbekannte Auswahl: $choice" -ForegroundColor Red }
	}

	if ($running) {
		Write-Host ''
		Read-Host 'Weiter mit Eingabetaste' | Out-Null
	}
}
