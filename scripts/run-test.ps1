# =====================================================================
# run-test.ps1  (WEB framework, Windows / PowerShell)
# Non-GUI JMeter runner with HTML dashboard generation.
#
#   .\scripts\run-test.ps1 -Plan SmokeTest -Env qa
#   .\scripts\run-test.ps1 -Plan LoadTest  -Env perf -Props @{users=200;rampup=120;duration=900}
#   # Competitive on-sale burst:
#   .\scripts\run-test.ps1 -Plan SpikeTest -Env qa -Props @{spike2_users=200;sync_group_size=200;sync_timeout=30000}
#
# Requires jmeter on PATH or $env:JMETER_HOME (and Java on PATH/JAVA_HOME).
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$Plan,   # SmokeTest|EndToEndJourney|LoadTest|StressTest|SpikeTest|SoakTest
  [string]$Env = "qa",
  [hashtable]$Props = @{}
)
$root      = Resolve-Path (Join-Path $PSScriptRoot "..")
$stamp     = Get-Date -Format "yyyyMMdd-HHmmss"
$runId     = "$Plan-$Env-$stamp"
$jmx       = Join-Path $root "jmx\$Plan.jmx"
$envFile   = Join-Path $root "config\env\$Env.properties"
$userProps = Join-Path $root "config\user.properties"
$resultDir = Join-Path $root "results\$runId"
$reportDir = Join-Path $root "reports\$runId"
$jtl       = Join-Path $resultDir "results.jtl"
$logFile   = Join-Path $resultDir "jmeter.log"

if (-not (Test-Path $jmx))     { throw "Plan not found: $jmx" }
if (-not (Test-Path $envFile)) { throw "Env file not found: $envFile" }
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null

$jmeter = if ($env:JMETER_HOME) { Join-Path $env:JMETER_HOME "bin\jmeter.bat" } else { "jmeter" }

$argList = @(
  "-n", "-t", $jmx,
  "-q", $envFile,
  "-p", $userProps,
  "-l", $jtl, "-j", $logFile,
  "-e", "-o", $reportDir,
  "-Jroutes_file=$(Join-Path $root 'data\routes.csv')",
  "-Juserdata_file=$(Join-Path $root 'data\userdata.csv')"
)
foreach ($k in $Props.Keys) { $argList += "-J$k=$($Props[$k])" }

Write-Host "=== Web Performance Run: $runId ===" -ForegroundColor Cyan
Write-Host "Plan : $jmx"
Write-Host "Env  : $envFile"
Write-Host "Report: $reportDir"

# JMeter on modern JDKs prints deprecation WARNINGs to stderr; trust the
# real exit code rather than letting PowerShell promote stderr to errors.
$ErrorActionPreference = 'Continue'
& $jmeter @argList 2>&1 | ForEach-Object { Write-Host $_ }
$code = $LASTEXITCODE
if ($code -ne 0) { throw "JMeter exited with code $code" }
Write-Host "`nHTML dashboard: $reportDir\index.html" -ForegroundColor Green
