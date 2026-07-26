$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$MobileDir = Join-Path $RootDir "mobile"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not installed or is not available in PATH."
}

Push-Location $MobileDir
try {
    flutter pub get
    dart format --output=none --set-exit-if-changed lib test
    flutter analyze --fatal-infos
    flutter test
    Write-Host "Mobile project is ready. Android and iOS host projects are versioned in the repository."
}
finally {
    Pop-Location
}
