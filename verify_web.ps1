param(
  [string]$BaseUrl = $env:NIUNIU_FRONTEND_BASE_URL,
  [string]$OutputDir = '.\build\playwright_smoke',
  [int]$WaitMs = 30000,
  [string]$Pages = 'overview,auction,node,market_center,yesterday,board_tier,board_height,limit_review,plate_rotation,news,ask_ai,jobs',
  [int]$ViewportWidth = 1600,
  [int]$ViewportHeight = 1200,
  [switch]$SkipInteractions
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Push-Location $scriptDir
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw 'Pass -BaseUrl or set NIUNIU_FRONTEND_BASE_URL before running verification.'
  }

  $nodeArgs = @(
    '.\scripts\playwright_smoke.js',
    '--base-url', $BaseUrl,
    '--output-dir', $OutputDir,
    '--wait-ms', $WaitMs,
    '--pages', $Pages,
    '--viewport-width', $ViewportWidth,
    '--viewport-height', $ViewportHeight
  )
  if ($SkipInteractions) {
    $nodeArgs += '--skip-interactions'
  }

  node @nodeArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  Pop-Location
}
