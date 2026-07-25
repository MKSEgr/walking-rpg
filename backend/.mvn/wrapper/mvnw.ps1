$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$PropertiesPath = Join-Path $PSScriptRoot "maven-wrapper.properties"

if (-not (Test-Path $PropertiesPath)) {
    throw "Missing $PropertiesPath"
}

$Properties = @{}
Get-Content $PropertiesPath | ForEach-Object {
    if ($_ -match "^([^#=]+)=(.*)$") {
        $Properties[$matches[1].Trim()] = $matches[2].Trim()
    }
}

$DistributionUrl = $Properties["distributionUrl"]
if ([string]::IsNullOrWhiteSpace($DistributionUrl)) {
    throw "distributionUrl is not configured"
}

if ($DistributionUrl -notmatch "apache-maven/([^/]+)/") {
    throw "Cannot parse Maven version from distributionUrl"
}

$MavenVersion = $matches[1]
$UserHome = [Environment]::GetFolderPath("UserProfile")
$InstallDir = Join-Path $UserHome ".m2\wrapper\dists\apache-maven-$MavenVersion"
$MavenCmd = Join-Path $InstallDir "bin\mvn.cmd"

if (-not (Test-Path $MavenCmd)) {
    $CacheRoot = Split-Path $InstallDir -Parent
    New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
    $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("walking-rpg-maven-" + [guid]::NewGuid())
    $Archive = Join-Path $TempRoot "maven.zip"
    New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

    Write-Host "Downloading Maven $MavenVersion..."
    Invoke-WebRequest -Uri $DistributionUrl -OutFile $Archive
    Expand-Archive -Path $Archive -DestinationPath $TempRoot -Force

    if (Test-Path $InstallDir) {
        Remove-Item -Recurse -Force $InstallDir
    }
    Move-Item -Path (Join-Path $TempRoot "apache-maven-$MavenVersion") -Destination $InstallDir
    Remove-Item -Recurse -Force $TempRoot
}

Push-Location $ProjectRoot
try {
    & $MavenCmd @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
