$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$MobileDir = Join-Path $RootDir "mobile"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not installed or is not available in PATH."
}

Push-Location $MobileDir
try {
    flutter create --platforms=android,ios --org com.walkingrpg --project-name walking_rpg_mobile .
    flutter pub get
    flutter analyze
    flutter test
    Write-Host "Mobile project is ready. Run: cd mobile; flutter run"
}
finally {
    Pop-Location
}
