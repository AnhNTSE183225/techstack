# ==============================================================================
# TECHSTACK Windows Local Observability Installer (VictoriaLogs)
# ==============================================================================
# Downloads and extracts official VictoriaLogs for Windows into user-local
# storage (%LOCALAPPDATA%\VictoriaLogs\bin\victoria-logs-prod.exe) with zero
# Administrator/UAC privileges and no installer residue.
#
# Usage:
#   .\observability\install.ps1
#   .\observability\install.ps1 -Version v1.54.0 -InstallDir "$env:LOCALAPPDATA\VictoriaLogs"
# ==============================================================================

param(
    [string]$Version = $(if ($env:VL_VERSION) { $env:VL_VERSION } else { "v1.54.0" }),
    [string]$InstallDir = $(if ($env:VL_INSTALL_DIR) { $env:VL_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "VictoriaLogs" }),
    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Ensure TLS 1.2+ on Windows PowerShell 5.1
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$binDir = Join-Path $InstallDir "bin"
$dataDir = Join-Path $InstallDir "data"
$exePath = Join-Path $binDir "victoria-logs-prod.exe"

if ((Test-Path $exePath) -and (-not $Force)) {
    Write-Host "VictoriaLogs already installed at: $exePath" -ForegroundColor Green
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    exit 0
}

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    # VictoriaLogs official Windows builds target amd64 (runs under Win11 ARM64 emulation as fallback)
    "amd64"
} else {
    "amd64"
}

$zipName = "victoria-logs-windows-$arch-$Version.zip"
$downloadUrl = "https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/$Version/$zipName"

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("victoria-logs-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  TECHSTACK Windows Observability Installer (VictoriaLogs $Version)" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Downloading $downloadUrl ..." -ForegroundColor Cyan

    $zipPath = Join-Path $tmpDir $zipName
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

    $extractDir = Join-Path $tmpDir "extracted"
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $foundExe = Get-ChildItem -Path $extractDir -Filter "victoria-logs-prod.exe" -Recurse -File | Select-Object -First 1
    if (-not $foundExe) {
        $foundExe = Get-ChildItem -Path $extractDir -Filter "*.exe" -Recurse -File | Select-Object -First 1
    }
    if (-not $foundExe) {
        throw "Could not find victoria-logs-prod.exe inside $zipName."
    }

    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }

    Copy-Item -Path $foundExe.FullName -Destination $exePath -Force

    $verOut = & $exePath --version 2>&1 | Select-Object -First 1
    Write-Host "  OK: Installed to $exePath ($verOut)" -ForegroundColor Green
    Write-Host "  OK: Storage directory ready at $dataDir" -ForegroundColor Green
} finally {
    if (Test-Path $tmpDir) {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit 0
