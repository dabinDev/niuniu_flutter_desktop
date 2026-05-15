param(
  [int]$Port = 18103,
  [string]$Bind = '127.0.0.1',
  [switch]$Build,
  [string]$ApiBaseUrl = $env:NIUNIU_API_BASE_URL,
  [string]$ClientDownloadUrl = $env:NIUNIU_CLIENT_DOWNLOAD_URL
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$webDir = Join-Path $scriptDir 'build\web'

if ($Build) {
  & (Join-Path $scriptDir 'build_web.ps1') `
    -ApiBaseUrl $ApiBaseUrl `
    -ClientDownloadUrl $ClientDownloadUrl
}

if (-not (Test-Path $webDir)) {
  throw "Missing build output: $webDir. Run .\\build_web.ps1 first or pass -Build."
}

Push-Location $webDir
try {
  python -m http.server $Port --bind $Bind
}
finally {
  Pop-Location
}
