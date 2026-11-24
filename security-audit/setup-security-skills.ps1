# ==============================================================================
# Setup Local Security Audit Skills & Gitleaks (Windows / PowerShell)
# ==============================================================================
# Clones upstream security skills into the GITIGNORED `security-audit/vendor/`
# folder so they remain local and are never committed to TECHSTACK.
# ==============================================================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vendorDir = Join-Path $scriptDir "vendor"

New-Item -ItemType Directory -Path $vendorDir -Force | Out-Null

Write-Host "[1/3] Checking Gitleaks CLI..." -ForegroundColor Cyan
if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Installing Gitleaks via winget..." -ForegroundColor Yellow
        winget install --id Gitleaks.Gitleaks --exact --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "  WARN: Install Gitleaks manually from https://github.com/gitleaks/gitleaks/releases" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] Gitleaks installed: $(gitleaks version)" -ForegroundColor Green
}

$repos = @(
    @{ Name = "vibe-security-skill"; Url = "https://github.com/raroque/vibe-security-skill.git" },
    @{ Name = "security-audit-skill"; Url = "https://github.com/cloudflare/security-audit-skill.git" }
)

$idx = 2
foreach ($repo in $repos) {
    $dest = Join-Path $vendorDir $repo.Name
    Write-Host "[$idx/3] Syncing $($repo.Name) into gitignored vendor/..." -ForegroundColor Cyan
    if (Test-Path (Join-Path $dest ".git")) {
        git -C $dest pull --ff-only
    } else {
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        git clone --depth 1 $repo.Url $dest
    }
    Write-Host "  [OK] Ready at $dest" -ForegroundColor Green
    $idx++
}

Write-Host ""
Write-Host "Security skills ready in $vendorDir (gitignored)." -ForegroundColor Green
