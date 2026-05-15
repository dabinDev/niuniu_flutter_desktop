param(
  [string]$ApiBaseUrl = $env:NIUNIU_API_BASE_URL,
  [string]$ClientDownloadUrl = $env:NIUNIU_CLIENT_DOWNLOAD_URL
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Push-Location $scriptDir
try {
  flutter build windows `
    --release `
    --dart-define="API_BASE_URL=$ApiBaseUrl" `
    --dart-define="CLIENT_DOWNLOAD_URL=$ClientDownloadUrl"
}
finally {
  Pop-Location
}
