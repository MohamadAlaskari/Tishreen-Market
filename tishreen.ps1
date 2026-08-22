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
# Drei Betriebsarten nach dem Vorbild von eportfolio.ps1 - aber an die
# Tishreen-Architektur angepasst: API und Web laufen auf dem Host (docs/09
# Abschnitt 4), Docker dient nur der Datenbank, und das Ziel-Deployment ist
# nginx + systemd (docs/09 Abschnitt 5), nicht Container. Die Betriebsarten
# unterscheiden sich also darin, WIE API und Web laufen. Sie haben eigene
# Ports und koennen nebeneinander laufen; sie teilen sich die EINE Datenbank
# aus infra/docker-compose.yml.
#
#   DEV       Quellcode-Betrieb: mvnw spring-boot:run, Vite-Dev-Server.
#             Profil dev. Zum Entwickeln.
#   NEARPROD  Gebautes Jar, gebautes Frontend (vite preview).
#             Profil dev. Prueft den Auslieferungsstand, nicht die
#             Produktivkonfiguration.
#   PROD      Dasselbe Jar, aber Profil prod: kein Swagger, kein Dev-Seed.
#             Laeuft nur mit echten Werten (DB_URL auf eine saubere
#             Datenbank); ohne sie beendet sich die API absichtlich.

[CmdletBinding()]
param(
	[ValidateSet('dev', 'nearprod', 'prod')]
	[string]$Mode = 'dev',
	[switch]$Check
)

Set-StrictMode -Version 2.0
Set-Location -Path $PSScriptRoot

$ComposeFile = 'infra\docker-compose.yml'
$EnvFile     = 'infra\.env'

$Modes = [ordered]@{
	'dev' = @{
		Label      = 'DEV / Quellcode-Betrieb'
		Profil     = 'dev'
		ApiVar     = 'DEV_API_PORT'
		ApiDefault = '8080'
		WebVar     = 'DEV_WEB_PORT'
		WebDefault = '3000'
		Hinweis    = 'Hot Reload: mvnw spring-boot:run und Vite-Dev-Server direkt auf dem Quellcode. Erster Start laedt Maven-Abhaengigkeiten, das dauert.'
	}
	'nearprod' = @{
		Label      = 'NEARPROD / Auslieferungsstand'
		Profil     = 'dev'
		ApiVar     = 'NEARPROD_API_PORT'
		ApiDefault = '8180'
		WebVar     = 'NEARPROD_WEB_PORT'
		WebDefault = '3100'
		Hinweis    = 'Gebautes Jar und gebautes Frontend (vite preview), aber weiterhin Profil dev: Dev-Seed, Swagger an. Prueft den Auslieferungsstand, nicht die Produktivkonfiguration.'
	}
	'prod' = @{
		Label      = 'PROD / Produktivkonfiguration'
		Profil     = 'prod'
		ApiVar     = 'PROD_API_PORT'
		ApiDefault = '8280'
		WebVar     = 'PROD_WEB_PORT'
		WebDefault = '3200'
		Hinweis    = 'Dasselbe Jar, aber Profil prod: kein Swagger, kein Dev-Seed. Braucht echte Werte (DB_URL auf eine saubere Datenbank); ohne sie beendet sich die API absichtlich.'
	}
}

$script:Mode = $Mode
$script:LastDockerExit = 0

# --------------------------------------------------------------------------
# Hilfsfunktionen
# --------------------------------------------------------------------------

function Get-Mode { return $Modes[$script:Mode] }

# Alle Compose-Aufrufe nennen Datei und Env-Datei ausdruecklich. "docker
# compose up" ohne -f scheitert mit "no configuration file provided"; das
# ist Absicht.
function Get-ComposeArgs {
	return @('-f', $ComposeFile, '--env-file', $EnvFile)
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
# Compose-Datei. POSTGRES_PASSWORD wird nirgends gelesen oder angezeigt.
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

function Get-DbUser { return Get-EnvValue -Name 'POSTGRES_USER' -Default 'tishreen' }
function Get-DbName { return Get-EnvValue -Name 'POSTGRES_DB' -Default 'tishreen' }
function Get-DbPort { return Get-EnvValue -Name 'POSTGRES_PORT' -Default '5432' }

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

	if (-not (Test-Path (Join-Path $PSScriptRoot $ComposeFile))) {
		Write-Host "Es fehlt $ComposeFile." -ForegroundColor Red
		$ok = $false
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
	Write-Host "  Postgres      127.0.0.1:$(Get-DbPort)  (eine Datenbank fuer alle Betriebsarten)"
}

# --------------------------------------------------------------------------
# Aktionen
# --------------------------------------------------------------------------

function Select-Betriebsart {
	Write-Head 'Betriebsart waehlen'
	$keys = @($Modes.Keys)
	for ($i = 0; $i -lt $keys.Count; $i++) {
		$m = $Modes[$keys[$i]]
		$api = Get-EnvValue -Name $m['ApiVar'] -Default $m['ApiDefault']
		$web = Get-EnvValue -Name $m['WebVar'] -Default $m['WebDefault']
		Write-Host ("  {0}  {1,-34} Profil {2}, API {3}, Web {4}" -f ($i + 1), $m['Label'], $m['Profil'], $api, $web)
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

	if ($script:Mode -eq 'prod') {
		Write-Host ''
		Write-Host 'Profil prod braucht echte Werte (DB_URL/DB_USER/DB_PASSWORD auf eine' -ForegroundColor Yellow
		Write-Host 'saubere Datenbank). Gegen die Dev-DB mit Dev-Seed V900 bricht Flyway' -ForegroundColor Yellow
		Write-Host 'absichtlich ab. Genau so ist die Fail-Fast-Regel gemeint; die Meldung' -ForegroundColor Yellow
		Write-Host 'steht danach im API-Fenster.' -ForegroundColor Yellow
	}

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
	Write-Head 'Status: Datenbank-Container'
	Invoke-Compose @('ps', '--format', 'table {{.Name}}\t{{.Status}}\t{{.Ports}}')
	Write-Host ''
	Write-Host 'API und Web laufen auf dem Host in eigenen Fenstern; ihren Zustand' -ForegroundColor DarkGray
	Write-Host 'zeigt Menuepunkt 8 (Gesundheit pruefen).' -ForegroundColor DarkGray
}

function Test-Gesundheit {
	$webPort = Get-WebPort
	$apiPort = Get-ApiPort
	$m = Get-Mode
	Write-Head "Gesundheit: $($m['Label'])"
	if (Invoke-Quiet 'docker' ((@('compose') + (Get-ComposeArgs)) + @('exec', '-T', 'postgres', 'pg_isready', '-U', (Get-DbUser), '-d', (Get-DbName)))) {
		Write-Host ("  {0,-30} bereit (127.0.0.1:{1})" -f 'Postgres (gemeinsam)', (Get-DbPort)) -ForegroundColor Green
	} else {
		Write-Host ("  {0,-30} nicht bereit (Menuepunkt 3)" -f 'Postgres (gemeinsam)') -ForegroundColor Red
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

function Test-GesundheitAlle {
	Write-Head 'Gesundheit aller Betriebsarten'
	$merken = $script:Mode
	foreach ($key in @($Modes.Keys)) {
		$script:Mode = $key
		Test-Gesundheit
	}
	$script:Mode = $merken
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
	Write-Head "psql als $(Get-DbUser) in $(Get-DbName)"
	Write-Host 'Die Datenbank ist fuer alle Betriebsarten dieselbe. Beenden mit \q' -ForegroundColor DarkGray
	Invoke-Compose @('exec', 'postgres', 'psql', '-U', (Get-DbUser), '-d', (Get-DbName))
}

function Invoke-ApiTests {
	Write-Head 'API-Tests auf dem Host'
	Write-Host 'Laufen gegen die Datenbank aus infra\docker-compose.yml (POSTGRES_PORT).' -ForegroundColor DarkGray
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

function Stop-Datenbank {
	Write-Head 'Datenbank stoppen'
	Write-Host 'Container und Daten bleiben; der naechste Start ist schnell.' -ForegroundColor DarkGray
	Invoke-Compose @('stop')
}

function Remove-DatenbankContainer {
	Write-Head 'Datenbank-Container entfernen'
	Write-Host 'Das Volume tishreen-pgdata und damit die Daten bleiben erhalten.' -ForegroundColor DarkGray
	Invoke-Compose @('down', '--remove-orphans')
}

function Remove-Datenbank {
	Write-Head 'Datenbank vollstaendig entfernen'
	Write-Host 'Das loescht den Postgres-Container UND das Volume tishreen-pgdata' -ForegroundColor Yellow
	Write-Host '(Docker-Name: infra_tishreen-pgdata). Die Datenbank ist fuer ALLE' -ForegroundColor Yellow
	Write-Host 'Betriebsarten dieselbe.' -ForegroundColor Yellow
	if (Confirm-Action 'Alle lokalen Datenbank-Daten sind danach weg.') {
		Invoke-Compose @('down', '-v', '--remove-orphans')
	}
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
	Write-Host ("               Spring-Profil {0}, API {1}, Oberflaeche {2}, Postgres {3}" -f $m['Profil'], (Get-ApiPort), (Get-WebPort), (Get-DbPort)) -ForegroundColor DarkGray
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
	Write-Host '   6  Status                        (Datenbank-Container)'
	Write-Host '   7  Gesundheit ALLER Betriebsarten'
	Write-Host '   8  Gesundheit pruefen            (Postgres, Oberflaeche, Health, OpenAPI)'
	Write-Host '   9  Logs folgen: Datenbank        (Strg+C beendet nur die Anzeige)'
	Write-Host '      API und Web loggen in ihren eigenen Fenstern.' -ForegroundColor DarkGray
	Write-Host ''
	Write-Host ' Arbeiten' -ForegroundColor White
	Write-Host '  10  psql in der Datenbank'
	Write-Host '  11  API-Tests auf dem Host        (.\mvnw.cmd verify)'
	Write-Host '  12  Web-Tests auf dem Host        (pnpm test in apps\web, Vitest)'
	Write-Host '  13  Lint auf dem Host             (pnpm lint ueber Turbo)'
	Write-Host '  14  Typecheck auf dem Host        (pnpm typecheck ueber Turbo)'
	Write-Host '  15  Format auf dem Host           (pnpm format ueber Turbo, Prettier)'
	Write-Host '  16  Mobile: Expo-Dev-Server       (neues Fenster)'
	Write-Host ''
	Write-Host ' Aufraeumen' -ForegroundColor White
	Write-Host '  17  Datenbank stoppen             (Container und Daten bleiben)'
	Write-Host '  18  Datenbank-Container entfernen (Volume und Daten bleiben)'
	Write-Host '  19  Datenbank vollstaendig entfernen   [inkl. Volume tishreen-pgdata]'
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
		'7'  { Test-GesundheitAlle }
		'8'  { Test-Gesundheit }
		'9'  { Watch-DbLogs }
		'10' { Open-Psql }
		'11' { Invoke-ApiTests }
		'12' { Invoke-WebTests }
		'13' { Invoke-TurboTask -Task 'lint' }
		'14' { Invoke-TurboTask -Task 'typecheck' }
		'15' { Invoke-TurboTask -Task 'format' }
		'16' { Start-Mobile }
		'17' { Stop-Datenbank }
		'18' { Remove-DatenbankContainer }
		'19' { Remove-Datenbank }
		'0'  { $running = $false }
		default { Write-Host ''; Write-Host "Unbekannte Auswahl: $choice" -ForegroundColor Red }
	}

	if ($running) {
		Write-Host ''
		Read-Host 'Weiter mit Eingabetaste' | Out-Null
	}
}
