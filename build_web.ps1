param(
  [string]$ApiBaseUrl = $env:NIUNIU_API_BASE_URL,
  [string]$ClientDownloadUrl = $env:NIUNIU_CLIENT_DOWNLOAD_URL
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-FrontendBuildInputs {
  param(
    [string]$ProjectDir
  )

  return @(
    (Join-Path $ProjectDir 'lib')
    (Join-Path $ProjectDir 'web')
    (Join-Path $ProjectDir 'assets')
    (Join-Path $ProjectDir 'pubspec.yaml')
    (Join-Path $ProjectDir 'pubspec.lock')
    (Join-Path $ProjectDir 'analysis_options.yaml')
    (Join-Path $ProjectDir 'build_web.ps1')
  ) | Where-Object { Test-Path -LiteralPath $_ }
}

function Get-LatestWriteTime {
  param(
    [string[]]$Paths
  )

  $latestWriteTimeUtc = $null
  foreach ($path in @($Paths)) {
    if (-not (Test-Path -LiteralPath $path)) {
      continue
    }

    $items = @()
    if (Test-Path -LiteralPath $path -PathType Container) {
      $items = @(Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue)
    }
    else {
      $items = @((Get-Item -LiteralPath $path -ErrorAction Stop))
    }

    foreach ($item in $items) {
      if ($null -eq $latestWriteTimeUtc -or $item.LastWriteTimeUtc -gt $latestWriteTimeUtc) {
        $latestWriteTimeUtc = $item.LastWriteTimeUtc
      }
    }
  }

  return $latestWriteTimeUtc
}

Push-Location $scriptDir
try {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    flutter build web `
      --release `
      --web-renderer html `
      --no-web-resources-cdn `
      --pwa-strategy=none `
      --dart-define="API_BASE_URL=$ApiBaseUrl" `
      --dart-define="CLIENT_DOWNLOAD_URL=$ClientDownloadUrl"

    $buildExitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($null -ne $buildExitCode -and $buildExitCode -ne 0) {
    throw "flutter build web failed with exit code $buildExitCode"
  }

  $buildDir = Join-Path $scriptDir 'build\web'
  $metaPath = Join-Path $buildDir '.niuniu_build_meta.json'
  $latestSourceWriteTimeUtc = Get-LatestWriteTime -Paths (Get-FrontendBuildInputs -ProjectDir $scriptDir)

  if (-not (Test-Path -LiteralPath $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
  }

  $cacheBustVersion = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
  $indexPath = Join-Path $buildDir 'index.html'
  $bootstrapPath = Join-Path $buildDir 'flutter_bootstrap.js'

  if (Test-Path -LiteralPath $indexPath) {
    $indexContent = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
    $indexContent = $indexContent -replace 'flutter_bootstrap\.js(?:\?v=[0-9A-Za-z_.-]+)?', "flutter_bootstrap.js?v=$cacheBustVersion"
    Set-Content -LiteralPath $indexPath -Value $indexContent -Encoding UTF8 -NoNewline
  }

  if (Test-Path -LiteralPath $bootstrapPath) {
    $bootstrapContent = Get-Content -LiteralPath $bootstrapPath -Raw -Encoding UTF8
    $bootstrapContent = $bootstrapContent -replace '"mainJsPath":"main\.dart\.js(?:\?v=[0-9A-Za-z_.-]+)?"', "`"mainJsPath`":`"main.dart.js?v=$cacheBustVersion`""
    Set-Content -LiteralPath $bootstrapPath -Value $bootstrapContent -Encoding UTF8 -NoNewline
  }

  $metadata = [ordered]@{
    api_base_url = $ApiBaseUrl
    built_at = (Get-Date).ToUniversalTime().ToString('o')
    cache_bust_version = $cacheBustVersion
    latest_source_write_time_utc = if ($null -ne $latestSourceWriteTimeUtc) {
      $latestSourceWriteTimeUtc.ToString('o')
    }
    else {
      $null
    }
  }

  $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metaPath -Encoding UTF8
}
finally {
  Pop-Location
}
