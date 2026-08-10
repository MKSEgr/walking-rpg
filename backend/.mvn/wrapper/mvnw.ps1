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

$DistributionSha256Sum = $Properties["distributionSha256Sum"]
if ($DistributionSha256Sum -cnotmatch "^[0-9a-f]{64}$") {
    throw "distributionSha256Sum must be 64 lowercase hexadecimal characters"
}

if ($DistributionUrl -notmatch "apache-maven/([^/]+)/") {
    throw "Cannot parse Maven version from distributionUrl"
}

$MavenVersion = $matches[1]
$UserHome = [Environment]::GetFolderPath("UserProfile")
$InstallDir = Join-Path $UserHome ".m2\wrapper\dists\apache-maven-$MavenVersion-$DistributionSha256Sum"
$MavenCmd = Join-Path $InstallDir "bin\mvn.cmd"

if (-not (Test-Path $MavenCmd)) {
    $CacheRoot = Split-Path $InstallDir -Parent
    New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
    $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("walking-rpg-maven-" + [guid]::NewGuid())
    $Archive = Join-Path $TempRoot "maven.zip"
    New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

    try {
        Write-Host "Downloading Maven $MavenVersion..."
        Invoke-WebRequest -Uri $DistributionUrl -OutFile $Archive
        $ActualSha256Sum = (Get-FileHash -Path $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($ActualSha256Sum -cne $DistributionSha256Sum) {
            throw "Maven distribution SHA-256 mismatch. Expected: $DistributionSha256Sum. Actual: $ActualSha256Sum."
        }
        Expand-Archive -Path $Archive -DestinationPath $TempRoot -Force

        if (Test-Path $InstallDir) {
            Remove-Item -Recurse -Force $InstallDir
        }
        Move-Item -Path (Join-Path $TempRoot "apache-maven-$MavenVersion") -Destination $InstallDir
    }
    finally {
        if (Test-Path $TempRoot) {
            Remove-Item -Recurse -Force $TempRoot
        }
    }
}

Push-Location $ProjectRoot
try {
    & $MavenCmd @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
