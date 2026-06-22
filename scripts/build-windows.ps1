param(
    [string]$FlutterExe = "flutter",
    [string]$OrganizationName = "Helixiora",
    [string]$SubmissionEndpoint = "",
    [string]$SubmissionSecret = "",
    [string]$AppVersion = "",
    [switch]$SkipAnalyze,
    [switch]$SkipTests,
    [switch]$ZipArtifact
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($env:OS -ne "Windows_NT") {
    throw "Windows builds must run on a Windows host."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
    if (-not $AppVersion.Trim()) {
        $AppVersion = (git -C $repoRoot describe --tags --always --dirty 2>$null).Trim()
        if (-not $AppVersion) {
            $AppVersion = "0.1.0-dev"
        }
    }

    & $FlutterExe --version | Out-Host
    & $FlutterExe pub get

    if (-not $SkipAnalyze) {
        & $FlutterExe analyze
    }

    if (-not $SkipTests) {
        & $FlutterExe test
    }

    $buildArgs = @(
        "build",
        "windows",
        "--release",
        "--dart-define=ORGANIZATION_NAME=$OrganizationName",
        "--dart-define=APP_VERSION=$AppVersion"
    )

    if ($SubmissionEndpoint.Trim()) {
        $buildArgs += "--dart-define=SUBMISSION_ENDPOINT=$SubmissionEndpoint"
    }
    if ($SubmissionSecret.Trim()) {
        $buildArgs += "--dart-define=SUBMISSION_SECRET=$SubmissionSecret"
    }

    & $FlutterExe @buildArgs

    $releaseDir = Join-Path $repoRoot "build/windows/x64/runner/Release"
    if (-not (Test-Path $releaseDir)) {
        throw "Windows release output was not found at $releaseDir"
    }

    $exe = Get-ChildItem -Path $releaseDir -Filter *.exe | Select-Object -First 1
    if ($null -eq $exe) {
        throw "No Windows executable was produced in $releaseDir"
    }

    Write-Host "Windows executable: $($exe.FullName)"

    if ($ZipArtifact) {
        $zipPath = Join-Path $repoRoot "build/windows/helixiora-endpoint-security-windows.zip"
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }

        Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath -Force
        Write-Host "Zipped artifact: $zipPath"
    }
}
finally {
    Pop-Location
}
